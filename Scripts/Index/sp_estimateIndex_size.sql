/*
================================================================================
Procedure: dbo.EstimateNonclusteredIndexSize

Purpose:
    Estimate the size of a proposed nonclustered index before creating it.

Method:
    Based on Microsoft's documented method for estimating the size of a
    nonclustered index.

    Microsoft Learn:
    https://learn.microsoft.com/en-us/sql/relational-databases/databases/
    estimate-the-size-of-a-nonclustered-index

Parameters:
    @SchemaName
    @TableName
    @KeyColumns
    @IncludeColumns
    @IsUnique
    @FillFactor

Example:

    EXEC dbo.EstimateNonclusteredIndexSize
        @SchemaName = 'dbo',
        @TableName = 'UPI_TLF_DATA',
        @KeyColumns =
            'UTD_PTR_SER_NUMBER,UTD_RET_REF_NUMBER',
        @IncludeColumns =
            'UTD_BANK_CODE,UTD_NETWORK,UTD_ADDITINAL_REFERENCE';

================================================================================
*/

CREATE OR ALTER PROCEDURE dbo.EstimateNonclusteredIndexSize
(
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

    /*========================================================================
      1. Validate parameters
    =========================================================================*/

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


    DECLARE @ObjectID INT;

    SELECT
        @ObjectID = OBJECT_ID
        (
            QUOTENAME(@SchemaName)
            + '.'
            + QUOTENAME(@TableName)
        );


    IF @ObjectID IS NULL
    BEGIN
        RAISERROR
        (
            'Table does not exist.',
            16,
            1
        );
        RETURN;
    END;


    /*========================================================================
      2. Get table row count
    =========================================================================*/

    DECLARE @NumRows BIGINT;

    SELECT
        @NumRows = SUM(p.rows)
    FROM sys.partitions AS p
    WHERE p.object_id = @ObjectID
      AND p.index_id IN (0,1);


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


    /*========================================================================
      3. Store KEY columns
    =========================================================================*/

    DECLARE @Key TABLE
    (
        Ordinal     INT IDENTITY(1,1),
        ColumnName  SYSNAME
    );


    /*
        XML splitter instead of STRING_SPLIT.
        This works on older SQL Server compatibility levels.
    */

    INSERT INTO @Key
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


    /*========================================================================
      4. Store INCLUDE columns
    =========================================================================*/

    DECLARE @Include TABLE
    (
        Ordinal     INT IDENTITY(1,1),
        ColumnName  SYSNAME
    );


    IF NULLIF(LTRIM(RTRIM(@IncludeColumns)), '') IS NOT NULL
    BEGIN

        INSERT INTO @Include
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


    /*========================================================================
      5. Validate requested columns
    =========================================================================*/

    IF EXISTS
    (
        SELECT 1
        FROM @Key K
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM sys.columns C
            WHERE C.object_id = @ObjectID
              AND C.name = K.ColumnName
        )
    )
    BEGIN

        SELECT
            K.ColumnName AS InvalidKeyColumn
        FROM @Key K
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM sys.columns C
            WHERE C.object_id = @ObjectID
              AND C.name = K.ColumnName
        );

        RAISERROR
        (
            'One or more key columns do not exist.',
            16,
            1
        );

        RETURN;

    END;


    IF EXISTS
    (
        SELECT 1
        FROM @Include I
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM sys.columns C
            WHERE C.object_id = @ObjectID
              AND C.name = I.ColumnName
        )
    )
    BEGIN

        SELECT
            I.ColumnName AS InvalidIncludeColumn
        FROM @Include I
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM sys.columns C
            WHERE C.object_id = @ObjectID
              AND C.name = I.ColumnName
        );

        RAISERROR
        (
            'One or more INCLUDE columns do not exist.',
            16,
            1
        );

        RETURN;

    END;


    /*========================================================================
      6. Find clustered index
    =========================================================================*/

    DECLARE @ClusteredIndexID INT;

    SELECT
        @ClusteredIndexID = I.index_id
    FROM sys.indexes AS I
    WHERE I.object_id = @ObjectID
      AND I.type = 1;


    DECLARE @ClusteredIndexIsUnique BIT = 0;


    IF @ClusteredIndexID IS NOT NULL
    BEGIN

        SELECT
            @ClusteredIndexIsUnique = I.is_unique
        FROM sys.indexes AS I
        WHERE I.object_id = @ObjectID
          AND I.index_id = @ClusteredIndexID;

    END;


    /*========================================================================
      7. Store all columns participating in the proposed index
    =========================================================================*/

    DECLARE @Columns TABLE
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


    /*========================================================================
      8. Add requested KEY columns
    =========================================================================*/

    INSERT INTO @Columns
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
        'INDEX_KEY',
        1,
        0,
        0,
        C.is_nullable,

        CASE
            WHEN TY.name IN
            (
                'varchar',
                'nvarchar',
                'varbinary',
                'sql_variant'
            )
            THEN 1
            ELSE 0
        END,

        CASE
            WHEN TY.name = 'nvarchar'
            THEN
                CASE
                    WHEN C.max_length = -1
                    THEN 0
                    ELSE C.max_length
                END

            WHEN TY.name IN
            (
                'varchar',
                'varbinary'
            )
            THEN
                CASE
                    WHEN C.max_length = -1
                    THEN 0
                    ELSE C.max_length
                END

            WHEN TY.name = 'sql_variant'
            THEN 8016

            ELSE C.max_length
        END,

        CASE
            WHEN TY.name IN
            (
                'varchar',
                'nvarchar',
                'varbinary',
                'sql_variant'
            )
            THEN 0
            ELSE C.max_length
        END

    FROM @Key K

    INNER JOIN sys.columns C
        ON C.object_id = @ObjectID
       AND C.name = K.ColumnName

    INNER JOIN sys.types TY
        ON TY.user_type_id = C.user_type_id;


    /*========================================================================
      9. Add INCLUDE columns
    =========================================================================*/

    INSERT INTO @Columns
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
        'INCLUDE',
        0,
        1,
        0,
        C.is_nullable,

        CASE
            WHEN TY.name IN
            (
                'varchar',
                'nvarchar',
                'varbinary',
                'sql_variant'
            )
            THEN 1
            ELSE 0
        END,

        CASE
            WHEN TY.name = 'nvarchar'
            THEN
                CASE
                    WHEN C.max_length = -1
                    THEN 0
                    ELSE C.max_length
                END

            WHEN TY.name IN
            (
                'varchar',
                'varbinary'
            )
            THEN
                CASE
                    WHEN C.max_length = -1
                    THEN 0
                    ELSE C.max_length
                END

            WHEN TY.name = 'sql_variant'
            THEN 8016

            ELSE C.max_length
        END,

        CASE
            WHEN TY.name IN
            (
                'varchar',
                'nvarchar',
                'varbinary',
                'sql_variant'
            )
            THEN 0
            ELSE C.max_length
        END

    FROM @Include INC

    INNER JOIN sys.columns C
        ON C.object_id = @ObjectID
       AND C.name = INC.ColumnName

    INNER JOIN sys.types TY
        ON TY.user_type_id = C.user_type_id;


    /*========================================================================
      10. Add clustered key as NCI row locator
    =========================================================================*/

    IF @ClusteredIndexID IS NOT NULL
    BEGIN

        INSERT INTO @Columns
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
            'CLUSTERED_KEY',
            1,
            0,
            1,
            C.is_nullable,

            CASE
                WHEN TY.name IN
                (
                    'varchar',
                    'nvarchar',
                    'varbinary',
                    'sql_variant'
                )
                THEN 1
                ELSE 0
            END,

            CASE
                WHEN TY.name = 'nvarchar'
                THEN
                    CASE
                        WHEN C.max_length = -1
                        THEN 0
                        ELSE C.max_length
                    END

                WHEN TY.name IN
                (
                    'varchar',
                    'varbinary'
                )
                THEN
                    CASE
                        WHEN C.max_length = -1
                        THEN 0
                        ELSE C.max_length
                    END

                WHEN TY.name = 'sql_variant'
                THEN 8016

                ELSE C.max_length
            END,

            CASE
                WHEN TY.name IN
                (
                    'varchar',
                    'nvarchar',
                    'varbinary',
                    'sql_variant'
                )
                THEN 0
                ELSE C.max_length
            END

        FROM sys.index_columns IC

        INNER JOIN sys.columns C
            ON C.object_id = IC.object_id
           AND C.column_id = IC.column_id

        INNER JOIN sys.types TY
            ON TY.user_type_id = C.user_type_id

        WHERE IC.object_id = @ObjectID
          AND IC.index_id = @ClusteredIndexID
          AND IC.key_ordinal > 0

          AND NOT EXISTS
          (
              SELECT 1
              FROM @Key K
              WHERE K.ColumnName = C.name
          );

    END;


    /*========================================================================
      11. Calculate NON-LEAF index row characteristics
    =========================================================================*/

    DECLARE
        @NumKeyCols              INT,
        @NumVariableKeyCols      INT,
        @FixedKeySize            BIGINT,
        @MaxVarKeySize           BIGINT,
        @IndexNullBitmap         INT,
        @VariableKeySize         BIGINT,
        @IndexRowSize            BIGINT,
        @IndexRowsPerPage        INT;


    SELECT
        @NumKeyCols =
            COUNT(*),

        @NumVariableKeyCols =
            SUM
            (
                CASE
                    WHEN IsVariable = 1
                    THEN 1
                    ELSE 0
                END
            ),

        @FixedKeySize =
            SUM
            (
                CASE
                    WHEN IsVariable = 0
                    THEN FixedBytes
                    ELSE 0
                END
            ),

        @MaxVarKeySize =
            SUM
            (
                CASE
                    WHEN IsVariable = 1
                    THEN MaxBytes
                    ELSE 0
                END
            )

    FROM @Columns

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


    /* Uniqueifier for nonunique clustered index */

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
        FROM @Columns
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


    /* Variable-length column overhead */

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


    /*
        Non-leaf index row size
    */

    SET @IndexRowSize =
          @FixedKeySize
        + @VariableKeySize
        + @IndexNullBitmap
        + 1
        + 6;


    /*
        Rows per non-leaf page
    */

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


    /*========================================================================
      12. Calculate LEAF-level characteristics
    =========================================================================*/

    DECLARE
        @NumLeafCols              INT,
        @NumVariableLeafCols      INT,
        @FixedLeafSize            BIGINT,
        @MaxVarLeafSize           BIGINT,
        @LeafNullBitmap           INT,
        @VariableLeafSize         BIGINT,
        @LeafRowSize              BIGINT,
        @LeafRowsPerPage          INT,
        @FreeRowsPerPage          INT,
        @NumLeafPages             BIGINT;


    SELECT
        @NumLeafCols =
            COUNT(*),

        @NumVariableLeafCols =
            SUM
            (
                CASE
                    WHEN IsVariable = 1
                    THEN 1
                    ELSE 0
                END
            ),

        @FixedLeafSize =
            SUM
            (
                CASE
                    WHEN IsVariable = 0
                    THEN FixedBytes
                    ELSE 0
                END
            ),

        @MaxVarLeafSize =
            SUM
            (
                CASE
                    WHEN IsVariable = 1
                    THEN MaxBytes
                    ELSE 0
                END
            )

    FROM @Columns;


    /*
        For a UNIQUE NCI, the row locator needs to be included
        at the leaf level.
    */

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
        ELSE
        BEGIN

            IF @ClusteredIndexIsUnique = 0
            BEGIN

                SET @NumLeafCols =
                    @NumLeafCols + 1;

                SET @NumVariableLeafCols =
                    @NumVariableLeafCols + 1;

                SET @MaxVarLeafSize =
                    @MaxVarLeafSize + 4;

            END;

        END;

    END;


    /*========================================================================
      13. Leaf NULL bitmap
    =========================================================================*/

    SET @LeafNullBitmap =
        2 + ((@NumLeafCols + 7) / 8);


    /*========================================================================
      14. Variable-length leaf columns
    =========================================================================*/

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


    /*========================================================================
      15. Leaf row size
    =========================================================================*/

    SET @LeafRowSize =
          @FixedLeafSize
        + @VariableLeafSize
        + @LeafNullBitmap
        + 1;


    /*========================================================================
      16. Leaf rows per page
    =========================================================================*/

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


    /*========================================================================
      17. Fill factor
    =========================================================================*/

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


    /*========================================================================
      18. Estimated leaf pages
    =========================================================================*/

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


    /*========================================================================
      19. Estimate NON-LEAF pages
    =========================================================================*/

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


    /*========================================================================
      20. Total estimated pages and size
    =========================================================================*/

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


    /*========================================================================
      21. Display proposed index column information
    =========================================================================*/

    SELECT
        C.ColumnName,
        C.SourceType,
        C.IsKey,
        C.IsInclude,
        C.IsLocator,
        TY.name AS DataType,
        C.isnullable AS IsNullable,
        C.MaxBytes,
        C.FixedBytes

    FROM
    (
        SELECT
            ColumnName,
            SourceType,
            IsKey,
            IsInclude,
            IsLocator,
            IsNullable,
            MaxBytes,
            FixedBytes
        FROM @Columns
    ) C

    LEFT JOIN sys.columns SC
        ON SC.object_id = @ObjectID
       AND SC.name = C.ColumnName

    LEFT JOIN sys.types TY
        ON TY.user_type_id = SC.user_type_id

    ORDER BY
        CASE
            WHEN C.SourceType = 'INDEX_KEY'
            THEN 1
            WHEN C.SourceType = 'CLUSTERED_KEY'
            THEN 2
            ELSE 3
        END;


    /*========================================================================
      22. FINAL ESTIMATE
    =========================================================================*/

    SELECT

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

        /* Row sizes */

        @IndexRowSize AS
            [NonLeafRowSize_Bytes],

        @LeafRowSize AS
            [LeafRowSize_Bytes],

        /* Rows per page */

        @IndexRowsPerPage AS
            [NonLeafRowsPerPage],

        @LeafRowsPerPage AS
            [LeafRowsPerPage],

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