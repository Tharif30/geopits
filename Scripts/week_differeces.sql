;WITH SnapshotData AS
(
    SELECT
        DBID,
        [DBNAME ],
        [SchemaName ],
        [TableName ],
        [rows ],
        [TotalSpaceMB],
        CAST([Date] AS date) AS SnapshotDate
    FROM [DBADB].[dbo].[TableSizeData]
    WHERE CAST([Date] AS date) IN
    (
        '2026-09-08',
        '2026-09-15',
        '2026-09-22'
    )
),
PivotData AS
(
    SELECT
        DBID,
        [DBNAME ],
        [SchemaName ],
        [TableName],

        MAX(CASE WHEN SnapshotDate = '2026-09-08'
                 THEN [rows ] END) AS Rows_08Sep,

        MAX(CASE WHEN SnapshotDate = '2026-09-15'
                 THEN [rows ] END) AS Rows_15Sep,

        MAX(CASE WHEN SnapshotDate = '2026-09-22'
                 THEN [rows ] END) AS Rows_22Sep,

        MAX(CASE WHEN SnapshotDate = '2026-09-08'
                 THEN [TotalSpaceMB] END) AS SizeMB_08Sep,

        MAX(CASE WHEN SnapshotDate = '2026-09-15'
                 THEN [TotalSpaceMB] END) AS SizeMB_15Sep,

        MAX(CASE WHEN SnapshotDate = '2026-09-22'
                 THEN [TotalSpaceMB] END) AS SizeMB_22Sep

    FROM SnapshotData
    GROUP BY
        DBID,
        [DBNAME ],
        [SchemaName ],
        [TableName]
)
SELECT
    DBID,
    [DBNAME ],
    [SchemaName ],
    [TableName],

    -- Row Count
    Rows_08Sep,
    Rows_15Sep,
    Rows_22Sep,

    ISNULL(Rows_15Sep, 0) - ISNULL(Rows_08Sep, 0) AS RowDiff_08to15,

    CAST(
        CASE
            WHEN Rows_08Sep = 0 THEN NULL
            ELSE
                ((CAST(Rows_15Sep AS decimal(38,2))
                  - Rows_08Sep)
                 / Rows_08Sep) * 100
        END
        AS decimal(18,2)
    ) AS RowPct_08to15,

    ISNULL(Rows_22Sep, 0) - ISNULL(Rows_15Sep, 0) AS RowDiff_15to22,

    CAST(
        CASE
            WHEN Rows_15Sep = 0 THEN NULL
            ELSE
                ((CAST(Rows_22Sep AS decimal(38,2))
                  - Rows_15Sep)
                 / Rows_15Sep) * 100
        END
        AS decimal(18,2)
    ) AS RowPct_15to22,

    -- Size
    SizeMB_08Sep,
    SizeMB_15Sep,
    SizeMB_22Sep,

    CAST(
        ISNULL(SizeMB_15Sep, 0) - ISNULL(SizeMB_08Sep, 0)
        AS decimal(18,2)
    ) AS SizeDiffMB_08to15,

    CAST(
        CASE
            WHEN SizeMB_08Sep = 0 THEN NULL
            ELSE
                ((SizeMB_15Sep - SizeMB_08Sep)
                 / SizeMB_08Sep) * 100
        END
        AS decimal(18,2)
    ) AS SizePct_08to15,

    CAST(
        ISNULL(SizeMB_22Sep, 0) - ISNULL(SizeMB_15Sep, 0)
        AS decimal(18,2)
    ) AS SizeDiffMB_15to22,

    CAST(
        CASE
            WHEN SizeMB_15Sep = 0 THEN NULL
            ELSE
                ((SizeMB_22Sep - SizeMB_15Sep)
                 / SizeMB_15Sep) * 100
        END
        AS decimal(18,2)
    ) AS SizePct_15to22

FROM PivotData
ORDER BY
    [DBNAME ],
    [SchemaName ],
    [TableName];