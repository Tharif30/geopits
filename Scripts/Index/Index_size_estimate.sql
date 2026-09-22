
DECLARE
    @SchemaName     SYSNAME = 'dbo',
    @TableName      SYSNAME = 'UPI_TLF_DATA',

    @KeyColumns     NVARCHAR(MAX) =
        'UTD_PTR_SER_NUMBER,UTD_RET_REF_NUMBER',

    @IncludeColumns NVARCHAR(MAX) =
        'UTD_BANK_CODE,UTD_NETWORK,UTD_ADDITINAL_REFERENCE',

    @IsUnique       BIT = 0,
    @FillFactor     INT = 100;


/*===========================================================================
  1. Get table information
===========================================================================*/

DECLARE @ObjectID INT;

SELECT @ObjectID = OBJECT_ID
(
    QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName)
);

IF @ObjectID IS NULL
BEGIN
    RAISERROR('Table does not exist.', 16, 1);
    RETURN;
END;


/*===========================================================================
  2. Get number of rows
===========================================================================*/

DECLARE @NumRows BIGINT;

SELECT
    @NumRows = SUM(p.rows)
FROM sys.partitions AS p
WHERE p.object_id = @ObjectID
  AND p.index_id IN (0, 1);

IF @NumRows IS NULL
BEGIN
    RAISERROR('Unable to determine table row count.', 16, 1);
    RETURN;
END;


/*===========================================================================
  3. Create list of requested KEY columns
===========================================================================*/

DECLARE @Key TABLE
(
    Ordinal INT IDENTITY(1,1),
    ColumnName SYSNAME
);

INSERT INTO @Key (ColumnName)
SELECT LTRIM(RTRIM(value))
FROM STRING_SPLIT(@KeyColumns, ',')
WHERE LTRIM(RTRIM(value)) <> '';


/*===========================================================================
  4. Create list of requested INCLUDE columns
===========================================================================*/

DECLARE @Include TABLE
(
    Ordinal INT IDENTITY(1,1),
    ColumnName SYSNAME
);

INSERT INTO @Include (ColumnName)
SELECT LTRIM(RTRIM(value))
FROM STRING_SPLIT(@IncludeColumns, ',')
WHERE LTRIM(RTRIM(value)) <> '';


/*===========================================================================
  5. Find clustered index
===========================================================================*/

DECLARE @ClusteredIndexID INT;

SELECT
    @ClusteredIndexID = i.index_id
FROM sys.indexes AS i
WHERE i.object_id = @ObjectID
  AND i.type = 1;


/*===========================================================================
  6. Build complete key/locator column information

     For a clustered table, the clustered key acts as the row locator.

     Microsoft documentation:
     Add clustered key columns that are not already present in the
     nonclustered index key.
===========================================================================*/

DECLARE @Columns TABLE
(
    ColumnName SYSNAME,
    SourceType VARCHAR(20),
    IsKey BIT,
    IsInclude BIT,
    IsLocator BIT,
    IsNullable BIT,
    IsVariable BIT,
    MaxBytes BIGINT,
    FixedBytes BIGINT
);


/*===========================================================================
  7. Add requested NONCLUSTERED INDEX KEY columns
===========================================================================*/

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
    c.name,
    'INDEX_KEY',
    1,
    0,
    0,
    c.is_nullable,

    CASE
        WHEN ty.name IN
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
        WHEN ty.name = 'nvarchar'
            THEN CASE
                    WHEN c.max_length = -1 THEN 0
                    ELSE c.max_length
                 END

        WHEN ty.name IN ('varchar','varbinary')
            THEN CASE
                    WHEN c.max_length = -1 THEN 0
                    ELSE c.max_length
                 END

        WHEN ty.name = 'sql_variant'
            THEN 8016

        ELSE c.max_length
    END,

    CASE
        WHEN ty.name IN
        (
            'varchar',
            'nvarchar',
            'varbinary',
            'sql_variant'
        )
        THEN 0
        ELSE c.max_length
    END

FROM @Key k
INNER JOIN sys.columns c
    ON c.object_id = @ObjectID
    AND c.name = k.ColumnName
INNER JOIN sys.types ty
    ON ty.user_type_id = c.user_type_id;


/*===========================================================================
  8. Add INCLUDE columns
===========================================================================*/

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
    c.name,
    'INCLUDE',
    0,
    1,
    0,
    c.is_nullable,

    CASE
        WHEN ty.name IN
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
        WHEN ty.name = 'nvarchar'
            THEN CASE
                    WHEN c.max_length = -1 THEN 0
                    ELSE c.max_length
                 END

        WHEN ty.name IN ('varchar','varbinary')
            THEN CASE
                    WHEN c.max_length = -1 THEN 0
                    ELSE c.max_length
                 END

        WHEN ty.name = 'sql_variant'
            THEN 8016

        ELSE c.max_length
    END,

    CASE
        WHEN ty.name IN
        (
            'varchar',
            'nvarchar',
            'varbinary',
            'sql_variant'
        )
        THEN 0
        ELSE c.max_length
    END

FROM @Include inc
INNER JOIN sys.columns c
    ON c.object_id = @ObjectID
    AND c.name = inc.ColumnName
INNER JOIN sys.types ty
    ON ty.user_type_id = c.user_type_id;


/*===========================================================================
  9. Add clustered key columns used as row locator

     Only clustered key columns NOT already present in the NCI key
     need to be added.

     This follows Microsoft's documented approach.
===========================================================================*/

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
        c.name,
        'CLUSTERED_KEY',
        1,
        0,
        1,
        c.is_nullable,

        CASE
            WHEN ty.name IN
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
            WHEN ty.name = 'nvarchar'
                THEN CASE
                        WHEN c.max_length = -1 THEN 0
                        ELSE c.max_length
                     END

            WHEN ty.name IN ('varchar','varbinary')
                THEN CASE
                        WHEN c.max_length = -1 THEN 0
                        ELSE c.max_length
                     END

            WHEN ty.name = 'sql_variant'
                THEN 8016

            ELSE c.max_length
        END,

        CASE
            WHEN ty.name IN
            (
                'varchar',
                'nvarchar',
                'varbinary',
                'sql_variant'
            )
            THEN 0
            ELSE c.max_length
        END

    FROM sys.index_columns ic
    INNER JOIN sys.columns c
        ON c.object_id = ic.object_id
        AND c.column_id = ic.column_id

    INNER JOIN sys.types ty
        ON ty.user_type_id = c.user_type_id

    WHERE ic.object_id = @ObjectID
      AND ic.index_id = @ClusteredIndexID
      AND ic.key_ordinal > 0

      AND NOT EXISTS
      (
          SELECT 1
          FROM @Key k
          WHERE k.ColumnName = c.name
      );

END;


/*===========================================================================
  10. If clustered index is NONUNIQUE

      SQL Server adds an additional uniqueifier.

      Microsoft documents additional locator overhead for nonunique
      clustered indexes.
===========================================================================*/

DECLARE @ClusteredIndexIsUnique BIT = 0;

SELECT
    @ClusteredIndexIsUnique = i.is_unique
FROM sys.indexes i
WHERE i.object_id = @ObjectID
  AND i.index_id = @ClusteredIndexID;


/*===========================================================================
  11. Calculate KEY-level variables
===========================================================================*/

DECLARE
    @NumKeyCols INT,
    @NumVariableKeyCols INT,
    @FixedKeySize BIGINT,
    @MaxVarKeySize BIGINT,
    @IndexNullBitmap INT,
    @VariableKeySize BIGINT,
    @IndexRowSize BIGINT,
    @IndexRowsPerPage INT;


/* Add uniqueifier when clustered index is nonunique */

SELECT
    @NumKeyCols =
        COUNT(*)
        +
        CASE
            WHEN @ClusteredIndexID IS NOT NULL
             AND @ClusteredIndexIsUnique = 0
            THEN 1
            ELSE 0
        END,

    @NumVariableKeyCols =
        SUM
        (
            CASE
                WHEN IsVariable = 1 THEN 1
                ELSE 0
            END
        )
        +
        CASE
            WHEN @ClusteredIndexID IS NOT NULL
             AND @ClusteredIndexIsUnique = 0
            THEN 1
            ELSE 0
        END,

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


/* Nonunique heap requires 8-byte RID */

IF @ClusteredIndexID IS NULL
   AND @IsUnique = 0
BEGIN

    SET @NumKeyCols = @NumKeyCols + 1;
    SET @NumVariableKeyCols = @NumVariableKeyCols + 1;
    SET @MaxVarKeySize = @MaxVarKeySize + 8;

END;


/* Null bitmap */

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


/* Variable key size */

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


/* Microsoft formula */

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
        8096.0 / (@IndexRowSize + 2)
    );


/*===========================================================================
  12. Calculate LEAF-level variables
===========================================================================*/

DECLARE
    @NumLeafCols INT,
    @NumVariableLeafCols INT,
    @FixedLeafSize BIGINT,
    @MaxVarLeafSize BIGINT,
    @LeafNullBitmap INT,
    @VariableLeafSize BIGINT,
    @LeafRowSize BIGINT,
    @LeafRowsPerPage INT,
    @FreeRowsPerPage INT,
    @NumLeafPages BIGINT;


/*
    Start with all key + INCLUDE columns.
*/

SELECT
    @NumLeafCols = COUNT(*),

    @NumVariableLeafCols =
        SUM
        (
            CASE
                WHEN IsVariable = 1 THEN 1
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
    Unique NCI:
    Data row locator must also be stored at leaf level.
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

        SET @NumLeafCols =
            @NumLeafCols
            +
            CASE
                WHEN @ClusteredIndexIsUnique = 0 THEN 1
                ELSE 0
            END;

        IF @ClusteredIndexIsUnique = 0
        BEGIN
            SET @NumVariableLeafCols =
                @NumVariableLeafCols + 1;

            SET @MaxVarLeafSize =
                @MaxVarLeafSize + 4;
        END

    END

END;


/* Leaf NULL bitmap */

SET @LeafNullBitmap =
    2 + ((@NumLeafCols + 7) / 8);


/* Variable leaf size */

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


/* Leaf rows per page */

SET @LeafRowsPerPage =
    FLOOR
    (
        8096.0 / (@LeafRowSize + 2)
    );


/* Free rows caused by fill factor */

SET @FreeRowsPerPage =
    FLOOR
    (
        8096.0
        *
        (
            (100 - @FillFactor) / 100.0
        )
        /
        (@LeafRowSize + 2)
    );


/* Number of leaf pages */

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


/*===========================================================================
  13. Calculate NON-LEAF levels
===========================================================================*/

DECLARE
    @NonLeafLevels INT,
    @NumIndexPages BIGINT = 0,
    @Level INT = 1,
    @PagesAtLevel BIGINT;


/*
    Number of non-leaf levels.

    We calculate iteratively instead of relying on the logarithm
    expression so that rounding of each level is explicit.
*/

SET @PagesAtLevel =
    CEILING
    (
        @NumLeafPages * 1.0
        /
        NULLIF(@IndexRowsPerPage, 0)
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
            NULLIF(@IndexRowsPerPage, 0)
        );

    SET @Level = @Level + 1;

END;


/* Root page */

SET @NumIndexPages =
    @NumIndexPages + 1;

SET @NonLeafLevels = @Level;


/*===========================================================================
  14. Calculate final size
===========================================================================*/

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


/*===========================================================================
  15. Display result
===========================================================================*/

SELECT

    @SchemaName AS [SchemaName],
    @TableName AS [TableName],

    @NumRows AS [TableRows],

    @KeyColumns AS [RequestedKeyColumns],
    @IncludeColumns AS [RequestedIncludeColumns],

    @IsUnique AS [IsUnique],
    @FillFactor AS [FillFactor],

    /* Key level */
    @NumKeyCols AS [KeyColumnsIncludingLocator],
    @FixedKeySize AS [FixedKeyBytes],
    @NumVariableKeyCols AS [VariableKeyColumns],
    @MaxVarKeySize AS [MaxVariableKeyBytes],

    @IndexRowSize AS [NonLeafRowSizeBytes],
    @IndexRowsPerPage AS [NonLeafRowsPerPage],

    /* Leaf level */
    @NumLeafCols AS [LeafColumns],
    @FixedLeafSize AS [FixedLeafBytes],
    @NumVariableLeafCols AS [VariableLeafColumns],
    @MaxVarLeafSize AS [MaxVariableLeafBytes],

    @LeafRowSize AS [LeafRowSizeBytes],
    @LeafRowsPerPage AS [LeafRowsPerPage],
    @FreeRowsPerPage AS [FreeRowsPerPage],

    /* Pages */
    @NumLeafPages AS [EstimatedLeafPages],
    @NumIndexPages AS [EstimatedNonLeafPages],
    @TotalPages AS [EstimatedTotalPages],

    /* Size */
    CAST(@TotalBytes / 1024.0 AS DECIMAL(18,2))
        AS [EstimatedSize_KB],

    @TotalMB AS [EstimatedSize_MB],

    @TotalGB AS [EstimatedSize_GB];