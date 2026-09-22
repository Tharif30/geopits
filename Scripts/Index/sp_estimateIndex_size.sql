USE DBADB;
GO

CREATE OR ALTER PROCEDURE dbo.EstimateNonclusteredIndexSize
(
    @DatabaseName     SYSNAME,
    @SchemaName       SYSNAME,
    @TableName        SYSNAME,
    @KeyColumns       NVARCHAR(MAX),
    @IncludeColumns   NVARCHAR(MAX) = NULL,
    @IsUnique         BIT = 0,
    @FillFactor       INT = 100
)
AS
BEGIN

    SET NOCOUNT ON;

    /*======================================================================
      1. Validate parameters
    ======================================================================*/

    IF DB_ID(@DatabaseName) IS NULL
    BEGIN
        RAISERROR
        (
            'Database does not exist or is not accessible: %s',
            16,
            1,
            @DatabaseName
        );
        RETURN;
    END;


    IF @FillFactor < 1 OR @FillFactor > 100
    BEGIN
        RAISERROR
        (
            'Fill factor must be between 1 and 100.',
            16,
            1
        );
        RETURN;
    END;


    /*======================================================================
      2. Variables
    ======================================================================*/

    DECLARE
        @SQL NVARCHAR(MAX),
        @ObjectID INT,
        @DatabaseID INT;


    SET @DatabaseID = DB_ID(@DatabaseName);


    /*======================================================================
      3. Get target table Object_ID
    ======================================================================*/

SET @SQL = N'
    SELECT
        @ObjectID_OUT = O.object_id
    FROM ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O
    INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S
        ON S.schema_id = O.schema_id
    WHERE O.type = ''U''
      AND O.name = @TableName_IN
      AND S.name = @SchemaName_IN;
';


EXEC sys.sp_executesql
    @SQL,
    N'@SchemaName_IN SYSNAME,
      @TableName_IN SYSNAME,
      @ObjectID_OUT INT OUTPUT',
    @SchemaName_IN = @SchemaName,
    @TableName_IN = @TableName,
    @ObjectID_OUT = @ObjectID OUTPUT;


IF @ObjectID IS NULL
BEGIN
    RAISERROR
    (
        'Table does not exist: %s.%s.%s',
        16,
        1,
        @DatabaseName,
        @SchemaName,
        @TableName
    );
    RETURN;
END;


    /*======================================================================
      4. Temporary tables
    ======================================================================*/

    CREATE TABLE #Key
    (
        Ordinal     INT IDENTITY(1,1),
        ColumnName  SYSNAME
    );


    CREATE TABLE #Include
    (
        Ordinal     INT IDENTITY(1,1),
        ColumnName  SYSNAME
    );


    CREATE TABLE #Columns
    (
        ColumnName      SYSNAME,
        SourceType      VARCHAR(20),
        IsKey           BIT,
        IsInclude       BIT,
        IsLocator       BIT,
        IsNullable      BIT,
        IsVariable      BIT,
        MaxBytes        BIGINT,
        FixedBytes      BIGINT
    );


    /*======================================================================
      5. Parse KEY columns

         XML is used instead of STRING_SPLIT so this works with
         older SQL Server compatibility levels.
    ======================================================================*/

    INSERT INTO #Key
    (
        ColumnName
    )
    SELECT
        LTRIM(RTRIM(T.C.value('.', 'SYSNAME')))
    FROM
    (
        SELECT
            CAST
            (
                '<x>'
                + REPLACE(@KeyColumns, ',', '</x><x>')
                + '</x>'
                AS XML
            ) AS XMLData
    ) AS X
    CROSS APPLY
        X.XMLData.nodes('/x') AS T(C);


    /*======================================================================
      6. Parse INCLUDE columns
    ======================================================================*/

    IF NULLIF(LTRIM(RTRIM(@IncludeColumns)), '') IS NOT NULL
    BEGIN

        INSERT INTO #Include
        (
            ColumnName
        )
        SELECT
            LTRIM(RTRIM(T.C.value('.', 'SYSNAME')))
        FROM
        (
            SELECT
                CAST
                (
                    '<x>'
                    + REPLACE(@IncludeColumns, ',', '</x><x>')
                    + '</x>'
                    AS XML
                ) AS XMLData
        ) AS X
        CROSS APPLY
            X.XMLData.nodes('/x') AS T(C);

    END;


    /*======================================================================
      7. Validate requested columns
    ======================================================================*/

    SET @SQL = N'

        IF EXISTS
        (
            SELECT 1
            FROM #Key K
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + QUOTENAME(@DatabaseName) + N'.sys.columns C
                WHERE C.object_id = @ObjectID
                  AND C.name = K.ColumnName
            )
        )
        BEGIN

            SELECT
                K.ColumnName AS InvalidKeyColumn
            FROM #Key K
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + QUOTENAME(@DatabaseName) + N'.sys.columns C
                WHERE C.object_id = @ObjectID
                  AND C.name = K.ColumnName
            );

            RAISERROR
            (
                ''One or more key columns do not exist.'',
                16,
                1
            );

            RETURN;

        END;


        IF EXISTS
        (
            SELECT 1
            FROM #Include I
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + QUOTENAME(@DatabaseName) + N'.sys.columns C
                WHERE C.object_id = @ObjectID
                  AND C.name = I.ColumnName
            )
        )
        BEGIN

            SELECT
                I.ColumnName AS InvalidIncludeColumn
            FROM #Include I
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ' + QUOTENAME(@DatabaseName) + N'.sys.columns C
                WHERE C.object_id = @ObjectID
                  AND C.name = I.ColumnName
            );

            RAISERROR
            (
                ''One or more INCLUDE columns do not exist.'',
                16,
                1
            );

            RETURN;

        END;

    ';


    EXEC sys.sp_executesql
        @SQL,
        N'@ObjectID INT',
        @ObjectID = @ObjectID;


    /*======================================================================
      8. Get table row count
    ======================================================================*/

    DECLARE @NumRows BIGINT;


    SET @SQL = N'

        SELECT
            @NumRows_OUT = SUM(P.rows)

        FROM ' + QUOTENAME(@DatabaseName) + N'.sys.partitions P

        WHERE P.object_id = @ObjectID
          AND P.index_id IN (0,1);

    ';


    EXEC sys.sp_executesql
        @SQL,
        N'@ObjectID INT,
          @NumRows_OUT BIGINT OUTPUT',
        @ObjectID = @ObjectID,
        @NumRows_OUT = @NumRows OUTPUT;


    IF @NumRows IS NULL
    BEGIN
        RAISERROR
        (
            'Unable to determine table row count.',
            16,
            1
        );
        RETURN;
    END;


    /*======================================================================
      9. Find clustered index
    ======================================================================*/

    DECLARE
        @ClusteredIndexID INT,
        @ClusteredIndexIsUnique BIT = 0;


    SET @SQL = N'

        SELECT
            @ClusteredIndexID_OUT = I.index_id,
            @ClusteredIndexIsUnique_OUT = I.is_unique

        FROM ' + QUOTENAME(@DatabaseName) + N'.sys.indexes I

        WHERE I.object_id = @ObjectID
          AND I.type = 1;

    ';


    EXEC sys.sp_executesql
        @SQL,
        N'@ObjectID INT,
          @ClusteredIndexID_OUT INT OUTPUT,
          @ClusteredIndexIsUnique_OUT BIT OUTPUT',
        @ObjectID = @ObjectID,
        @ClusteredIndexID_OUT = @ClusteredIndexID OUTPUT,
        @ClusteredIndexIsUnique_OUT = @ClusteredIndexIsUnique OUTPUT;


    /*======================================================================
      10. Add proposed KEY columns
    ======================================================================*/

    SET @SQL = N'

        INSERT INTO #Columns
        (
            ColumnName,
            SourceType,
            IsKey,
            IsInclude,
            IsLocator,
            IsNullable,
            IsVariable,
            MaxBytes,
            FixedBytes
        )

        SELECT
            C.name,
            ''INDEX_KEY'',
            1,
            0,
            0,
            C.is_nullable,

            CASE
                WHEN TY.name IN
                (
                    ''varchar'',
                    ''nvarchar'',
                    ''varbinary'',
                    ''sql_variant''
                )
                THEN 1
                ELSE 0
            END,

            CASE
                WHEN TY.name = ''nvarchar''
                THEN
                    CASE
                        WHEN C.max_length = -1
                        THEN 0
                        ELSE C.max_length
                    END

                WHEN TY.name IN
                (
                    ''varchar'',
                    ''varbinary''
                )
                THEN
                    CASE
                        WHEN C.max_length = -1
                        THEN 0
                        ELSE C.max_length
                    END

                WHEN TY.name = ''sql_variant''
                THEN 8016

                ELSE C.max_length
            END,

            CASE
                WHEN TY.name IN
                (
                    ''varchar'',
                    ''nvarchar'',
                    ''varbinary'',
                    ''sql_variant''
                )
                THEN 0
                ELSE C.max_length
            END

        FROM #Key K

        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns C
            ON C.object_id = @ObjectID
           AND C.name = K.ColumnName

        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.types TY
            ON TY.user_type_id = C.user_type_id;

    ';


    EXEC sys.sp_executesql
        @SQL,
        N'@ObjectID INT',
        @ObjectID = @ObjectID;


    /*======================================================================
      11. Add proposed INCLUDE columns
    ======================================================================*/

    SET @SQL = N'

        INSERT INTO #Columns
        (
            ColumnName,
            SourceType,
            IsKey,
            IsInclude,
            IsLocator,
            IsNullable,
            IsVariable,
            MaxBytes,
            FixedBytes
        )

        SELECT
            C.name,
            ''INCLUDE'',
            0,
            1,
            0,
            C.is_nullable,

            CASE
                WHEN TY.name IN
                (
                    ''varchar'',
                    ''nvarchar'',
                    ''varbinary'',
                    ''sql_variant''
                )
                THEN 1
                ELSE 0
            END,

            CASE
                WHEN TY.name = ''nvarchar''
                THEN
                    CASE
                        WHEN C.max_length = -1
                        THEN 0
                        ELSE C.max_length
                    END

                WHEN TY.name IN
                (
                    ''varchar'',
                    ''varbinary''
                )
                THEN
                    CASE
                        WHEN C.max_length = -1
                        THEN 0
                        ELSE C.max_length
                    END

                WHEN TY.name = ''sql_variant''
                THEN 8016

                ELSE C.max_length
            END,

            CASE
                WHEN TY.name IN
                (
                    ''varchar'',
                    ''nvarchar'',
                    ''varbinary'',
                    ''sql_variant''
                )
                THEN 0
                ELSE C.max_length
            END

        FROM #Include INC

        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns C
            ON C.object_id = @ObjectID
           AND C.name = INC.ColumnName

        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.types TY
            ON TY.user_type_id = C.user_type_id;

    ';


    EXEC sys.sp_executesql
        @SQL,
        N'@ObjectID INT',
        @ObjectID = @ObjectID;


    /*======================================================================
      12. Add clustered key columns as row locator
    ======================================================================*/

    IF @ClusteredIndexID IS NOT NULL
    BEGIN

        SET @SQL = N'

            INSERT INTO #Columns
            (
                ColumnName,
                SourceType,
                IsKey,
                IsInclude,
                IsLocator,
                IsNullable,
                IsVariable,
                MaxBytes,
                FixedBytes
            )

            SELECT
                C.name,
                ''CLUSTERED_KEY'',
                1,
                0,
                1,
                C.is_nullable,

                CASE
                    WHEN TY.name IN
                    (
                        ''varchar'',
                        ''nvarchar'',
                        ''varbinary'',
                        ''sql_variant''
                    )
                    THEN 1
                    ELSE 0
                END,

                CASE
                    WHEN TY.name = ''nvarchar''
                    THEN
                        CASE
                            WHEN C.max_length = -1
                            THEN 0
                            ELSE C.max_length
                        END

                    WHEN TY.name IN
                    (
                        ''varchar'',
                        ''varbinary''
                    )
                    THEN
                        CASE
                            WHEN C.max_length = -1
                            THEN 0
                            ELSE C.max_length
                        END

                    WHEN TY.name = ''sql_variant''
                    THEN 8016

                    ELSE C.max_length
                END,

                CASE
                    WHEN TY.name IN
                    (
                        ''varchar'',
                        ''nvarchar'',
                        ''varbinary'',
                        ''sql_variant''
                    )
                    THEN 0
                    ELSE C.max_length
                END

            FROM ' + QUOTENAME(@DatabaseName) + N'.sys.index_columns IC

            INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns C
                ON C.object_id = IC.object_id
               AND C.column_id = IC.column_id

            INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.types TY
                ON TY.user_type_id = C.user_type_id

            WHERE IC.object_id = @ObjectID
              AND IC.index_id = @ClusteredIndexID
              AND IC.key_ordinal > 0

              AND NOT EXISTS
              (
                  SELECT 1
                  FROM #Key K
                  WHERE K.ColumnName = C.name
              );

        ';


        EXEC sys.sp_executesql
            @SQL,
            N'@ObjectID INT,
              @ClusteredIndexID INT',
            @ObjectID = @ObjectID,
            @ClusteredIndexID = @ClusteredIndexID;

    END;


    /*======================================================================
      13. Calculate NON-LEAF row characteristics
    ======================================================================*/

    DECLARE
        @NumKeyCols          INT,
        @NumVariableKeyCols  INT,
        @FixedKeySize        BIGINT,
        @MaxVarKeySize       BIGINT,
        @IndexNullBitmap     INT,
        @VariableKeySize     BIGINT,
        @IndexRowSize        BIGINT,
        @IndexRowsPerPage    INT;


    SELECT
        @NumKeyCols =
            COUNT(*),

        @NumVariableKeyCols =
            ISNULL
            (
                SUM
                (
                    CASE
                        WHEN IsVariable = 1
                        THEN 1
                        ELSE 0
                    END
                ),
                0
            ),

        @FixedKeySize =
            ISNULL
            (
                SUM
                (
                    CASE
                        WHEN IsVariable = 0
                        THEN FixedBytes
                        ELSE 0
                    END
                ),
                0
            ),

        @MaxVarKeySize =
            ISNULL
            (
                SUM
                (
                    CASE
                        WHEN IsVariable = 1
                        THEN MaxBytes
                        ELSE 0
                    END
                ),
                0
            )

    FROM #Columns

    WHERE IsKey = 1;


    /* Heap row locator */

    IF @ClusteredIndexID IS NULL
       AND @IsUnique = 0
    BEGIN

        SET @NumKeyCols =
            @NumKeyCols + 1;

        SET @NumVariableKeyCols =
            @NumVariableKeyCols + 1;

        SET @MaxVarKeySize =
            @MaxVarKeySize + 8;

    END;


    /* Nonunique clustered key uniqueifier */

    IF @ClusteredIndexID IS NOT NULL
       AND @ClusteredIndexIsUnique = 0
    BEGIN

        SET @NumKeyCols =
            @NumKeyCols + 1;

        SET @NumVariableKeyCols =
            @NumVariableKeyCols + 1;

        SET @MaxVarKeySize =
            @MaxVarKeySize + 4;

    END;


    /* NULL bitmap */

    IF EXISTS
    (
        SELECT 1
        FROM #Columns
        WHERE IsKey = 1
          AND IsNullable = 1
    )
    BEGIN

        SET @IndexNullBitmap =
            2 + ((@NumKeyCols + 7) / 8);

    END
    ELSE
    BEGIN

        SET @IndexNullBitmap = 0;

    END;


    /* Variable-length columns */

    IF @NumVariableKeyCols > 0
    BEGIN

        SET @VariableKeySize =
              2
            + (@NumVariableKeyCols * 2)
            + @MaxVarKeySize;

    END
    ELSE
    BEGIN

        SET @VariableKeySize = 0;

    END;


    /* Non-leaf row size */

    SET @IndexRowSize =
          @FixedKeySize
        + @VariableKeySize
        + @IndexNullBitmap
        + 1
        + 6;


    /* Rows per non-leaf page */

    SET @IndexRowsPerPage =
        FLOOR
        (
            8096.0 /
            NULLIF
            (
                @IndexRowSize + 2,
                0
            )
        );


    /*======================================================================
      14. Calculate LEAF-level characteristics
    ======================================================================*/

    DECLARE
        @NumLeafCols          INT,
        @NumVariableLeafCols  INT,
        @FixedLeafSize        BIGINT,
        @MaxVarLeafSize       BIGINT,
        @LeafNullBitmap       INT,
        @VariableLeafSize     BIGINT,
        @LeafRowSize          BIGINT,
        @LeafRowsPerPage      INT,
        @FreeRowsPerPage      INT,
        @NumLeafPages         BIGINT;


    SELECT
        @NumLeafCols =
            COUNT(*),

        @NumVariableLeafCols =
            ISNULL
            (
                SUM
                (
                    CASE
                        WHEN IsVariable = 1
                        THEN 1
                        ELSE 0
                    END
                ),
                0
            ),

        @FixedLeafSize =
            ISNULL
            (
                SUM
                (
                    CASE
                        WHEN IsVariable = 0
                        THEN FixedBytes
                        ELSE 0
                    END
                ),
                0
            ),

        @MaxVarLeafSize =
            ISNULL
            (
                SUM
                (
                    CASE
                        WHEN IsVariable = 1
                        THEN MaxBytes
                        ELSE 0
                    END
                ),
                0
            )

    FROM #Columns;


    /* Unique NCI leaf locator */

    IF @IsUnique = 1
    BEGIN

        IF @ClusteredIndexID IS NULL
        BEGIN

            SET @NumLeafCols =
                @NumLeafCols + 1;

            SET @NumVariableLeafCols =
                @NumVariableLeafCols + 1;

            SET @MaxVarLeafSize =
                @MaxVarLeafSize + 8;

        END
        ELSE IF @ClusteredIndexIsUnique = 0
        BEGIN

            SET @NumLeafCols =
                @NumLeafCols + 1;

            SET @NumVariableLeafCols =
                @NumVariableLeafCols + 1;

            SET @MaxVarLeafSize =
                @MaxVarLeafSize + 4;

        END;

    END;


    /* Leaf NULL bitmap */

    SET @LeafNullBitmap =
        2 + ((@NumLeafCols + 7) / 8);


    /* Variable leaf columns */

    IF @NumVariableLeafCols > 0
    BEGIN

        SET @VariableLeafSize =
              2
            + (@NumVariableLeafCols * 2)
            + @MaxVarLeafSize;

    END
    ELSE
    BEGIN

        SET @VariableLeafSize = 0;

    END;


    /* Leaf row size */

    SET @LeafRowSize =
          @FixedLeafSize
        + @VariableLeafSize
        + @LeafNullBitmap
        + 1;


    /* Rows per leaf page */

    SET @LeafRowsPerPage =
        FLOOR
        (
            8096.0 /
            NULLIF
            (
                @LeafRowSize + 2,
                0
            )
        );


    /*======================================================================
      15. Fill factor
    ======================================================================*/

    SET @FreeRowsPerPage =
        FLOOR
        (
            8096.0
            *
            (
                (100 - @FillFactor) / 100.0
            )
            /
            NULLIF
            (
                @LeafRowSize + 2,
                0
            )
        );


    /*======================================================================
      16. Estimate leaf pages
    ======================================================================*/

    SET @NumLeafPages =
        CEILING
        (
            @NumRows * 1.0
            /
            NULLIF
            (
                @LeafRowsPerPage - @FreeRowsPerPage,
                0
            )
        );


    /*======================================================================
      17. Estimate non-leaf pages
    ======================================================================*/

    DECLARE
        @NumIndexPages BIGINT = 0,
        @PagesAtLevel BIGINT,
        @NonLeafLevels INT = 1;


    SET @PagesAtLevel =
        CEILING
        (
            @NumLeafPages * 1.0
            /
            NULLIF
            (
                @IndexRowsPerPage,
                0
            )
        );


    WHILE @PagesAtLevel > 1
    BEGIN

        SET @NumIndexPages =
            @NumIndexPages + @PagesAtLevel;

        SET @PagesAtLevel =
            CEILING
            (
                @PagesAtLevel * 1.0
                /
                NULLIF
                (
                    @IndexRowsPerPage,
                    0
                )
            );

        SET @NonLeafLevels =
            @NonLeafLevels + 1;

    END;


    /* Root page */

    SET @NumIndexPages =
        @NumIndexPages + 1;


    /*======================================================================
      18. Final size
    ======================================================================*/

    DECLARE
        @TotalPages BIGINT,
        @TotalBytes BIGINT,
        @TotalMB DECIMAL(18,2),
        @TotalGB DECIMAL(18,2);


    SET @TotalPages =
          @NumLeafPages
        + @NumIndexPages;


    SET @TotalBytes =
        @TotalPages * 8192;


    SET @TotalMB =
        @TotalBytes / 1024.0 / 1024.0;


    SET @TotalGB =
        @TotalBytes / 1024.0 / 1024.0 / 1024.0;


    /*======================================================================
      19. Show column calculation details
    ======================================================================*/

    SET @SQL = N'

        SELECT
            C.ColumnName,
            C.SourceType,
            C.IsKey,
            C.IsInclude,
            C.IsLocator,
            TY.name AS DataType,
            C.IsNullable,
            C.MaxBytes,
            C.FixedBytes

        FROM #Columns C

        LEFT JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns SC
            ON SC.object_id = @ObjectID
           AND SC.name = C.ColumnName

        LEFT JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.types TY
            ON TY.user_type_id = SC.user_type_id

        ORDER BY
            CASE
                WHEN C.SourceType = ''INDEX_KEY''
                THEN 1

                WHEN C.SourceType = ''CLUSTERED_KEY''
                THEN 2

                ELSE 3
            END,

            C.ColumnName;

    ';


    EXEC sys.sp_executesql
        @SQL,
        N'@ObjectID INT',
        @ObjectID = @ObjectID;


    /*======================================================================
      20. Final result
    ======================================================================*/

    SELECT

        @DatabaseName AS [DatabaseName],

        @SchemaName AS [SchemaName],

        @TableName AS [TableName],

        @NumRows AS [TableRows],

        @KeyColumns AS [ProposedKeyColumns],

        ISNULL
        (
            @IncludeColumns,
            ''
        ) AS [ProposedIncludeColumns],

        @IsUnique AS [IsUnique],

        @FillFactor AS [FillFactor],

        @ClusteredIndexID AS [ClusteredIndexID],

        @ClusteredIndexIsUnique AS
            [ClusteredIndexIsUnique],

        /* Row size */

        @IndexRowSize AS
            [NonLeafRowSize_Bytes],

        @LeafRowSize AS
            [LeafRowSize_Bytes],

        /* Rows per page */

        @IndexRowsPerPage AS
            [NonLeafRowsPerPage],

        @LeafRowsPerPage AS
            [LeafRowsPerPage],

        /* Levels */

        @NonLeafLevels AS
            [EstimatedNonLeafLevels],

        /* Pages */

        @NumLeafPages AS
            [EstimatedLeafPages],

        @NumIndexPages AS
            [EstimatedNonLeafPages],

        @TotalPages AS
            [EstimatedTotalPages],

        /* Size */

        CAST
        (
            @TotalBytes / 1024.0
            AS DECIMAL(18,2)
        ) AS [EstimatedSize_KB],

        @TotalMB AS
            [EstimatedSize_MB],

        @TotalGB AS
            [EstimatedSize_GB];

END;
GO