--Count Missing Index Suggestions per Column per Table

;WITH MissingIndexes AS
(
    SELECT
        DB_NAME(mid.database_id) AS DatabaseName,
        OBJECT_NAME(mid.object_id, mid.database_id) AS TableName,
        mid.equality_columns,
        mid.inequality_columns
    FROM sys.dm_db_missing_index_group_stats AS migs
    JOIN sys.dm_db_missing_index_groups AS mig
        ON migs.group_handle = mig.index_group_handle
    JOIN sys.dm_db_missing_index_details AS mid
        ON mig.index_handle = mid.index_handle
    WHERE mid.database_id = DB_ID()
),
SplitColumns AS
(
    -- Split equality columns
    SELECT 
        TableName,
        LTRIM(RTRIM(value)) AS ColumnName
    FROM MissingIndexes
    CROSS APPLY string_split(
        REPLACE(REPLACE(COALESCE(equality_columns, ''), '[', ''), ']', ''),
        ','
    )

    UNION ALL

    -- Split inequality columns
    SELECT 
        TableName,
        LTRIM(RTRIM(value)) AS ColumnName
    FROM MissingIndexes
    CROSS APPLY string_split(
        REPLACE(REPLACE(COALESCE(inequality_columns, ''), '[', ''), ']', ''),
        ','
    )
)
SELECT 
    TableName,
    ColumnName,
    COUNT(*) AS TimesSuggested
FROM SplitColumns
WHERE ColumnName <> ''
GROUP BY TableName, ColumnName
ORDER BY TimesSuggested DESC, TableName, ColumnName;
