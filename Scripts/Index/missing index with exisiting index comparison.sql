-- Existing Indexes
WITH ExistingIndexes AS (
    SELECT
        i.object_id,
        i.index_id,
        i.name AS IndexName,
        kc.KeyColumns,
        ic.IncludedColumns
    FROM sys.indexes i
    JOIN sys.tables t ON i.object_id = t.object_id
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    OUTER APPLY (
        SELECT STRING_AGG(c.name + CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END, ', ') 
        WITHIN GROUP (ORDER BY ic.key_ordinal) AS KeyColumns
        FROM sys.index_columns ic
        JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
    ) kc
    OUTER APPLY (
        SELECT STRING_AGG(c.name, ', ') AS IncludedColumns
        FROM sys.index_columns ic
        JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
    ) ic
)

-- Missing Index Suggestions
, MissingIndexes AS (
    SELECT 
        DB_NAME(mid.database_id) AS DatabaseName,
        OBJECT_NAME(mid.object_id, mid.database_id) AS TableName,
        migs.user_seeks AS UserSeeks,
        migs.last_user_seek AS LastUserSeek,
        CAST(migs.avg_user_impact AS VARCHAR(5)) + '%' AS EstimatedImprovementPercent,
        mid.equality_columns AS Key_Columns,
        mid.inequality_columns AS InequalityColumns,
        mid.included_columns AS IncludedColumns,
        'CREATE NONCLUSTERED INDEX [IX_' + OBJECT_NAME(mid.object_id, mid.database_id) + '_' 
        + REPLACE(REPLACE(ISNULL(mid.equality_columns, ''), ', ', '_'), '[', '') 
        + CASE WHEN mid.inequality_columns IS NOT NULL THEN '_' + REPLACE(REPLACE(mid.inequality_columns, ', ', '_'), '[', '') 
        ELSE '' END
        + '] ON [' + DB_NAME(mid.database_id) + '].[' + SCHEMA_NAME(o.schema_id) + '].[' 
        + OBJECT_NAME(mid.object_id, mid.database_id) + '] (' + ISNULL(mid.equality_columns, '') 
        + CASE WHEN mid.inequality_columns IS NOT NULL THEN CASE WHEN mid.equality_columns IS NOT NULL THEN ',' ELSE '' END 
        + mid.inequality_columns ELSE '' END
        + ') ' + CASE WHEN mid.included_columns IS NOT NULL THEN 'INCLUDE (' + mid.included_columns + ')' ELSE '' END
        AS CreateIndexStatement
    FROM sys.dm_db_missing_index_group_stats AS migs
    JOIN sys.dm_db_missing_index_groups AS mig ON migs.group_handle = mig.index_group_handle
    JOIN sys.dm_db_missing_index_details AS mid ON mig.index_handle = mid.index_handle
    JOIN sys.objects o ON mid.object_id = o.object_id
    WHERE mid.database_id = DB_ID()
    AND migs.user_seeks > 2000
    AND CAST(migs.avg_user_impact AS INT) > 90
)

-- Comparing Existing and Missing Indexes
SELECT
    m.DatabaseName,
    m.TableName,
    m.UserSeeks,
    m.LastUserSeek,
    m.EstimatedImprovementPercent,
    m.Key_Columns,
    m.InequalityColumns,
    m.IncludedColumns,
    m.CreateIndexStatement
FROM MissingIndexes m
LEFT JOIN ExistingIndexes e
    ON e.KeyColumns = m.Key_Columns
    AND e.IncludedColumns = m.IncludedColumns
WHERE e.IndexName IS NULL
ORDER BY m.UserSeeks DESC, m.EstimatedImprovementPercent DESC;



SELECT
    i.name,
    i.type_desc
FROM sys.indexes i
WHERE object_id = OBJECT_ID('dbo.tbl_master_telecom_plans');


exec sp_helpindex 'dbo.tbl_user_subscriptions_i2'

exec sp_spaceused 'dbo.tbl_user_subscriptions_i2'