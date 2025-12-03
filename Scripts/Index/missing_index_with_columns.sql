--it will give multiple suggestions so give it too chatgpt and summarize the indexes

SELECT 
    DB_NAME(mid.database_id) AS DatabaseName,
    OBJECT_NAME(mid.object_id, mid.database_id) AS TableName,

    migs.user_seeks AS UserSeeks,
    migs.last_user_seek AS LastUserSeek,
    CAST(migs.avg_user_impact AS VARCHAR(5)) + '%' AS EstimatedImprovementPercent,

    ---- KEY COLUMNS ----
    mid.equality_columns AS KeY_Columns,
    mid.inequality_columns AS InequalityColumns,

    ---- INCLUDED COLUMNS ----
    mid.included_columns AS IncludedColumns,

    ---- FULL CREATE INDEX STATEMENT ----
    'CREATE NONCLUSTERED INDEX [IX_' 
        + OBJECT_NAME(mid.object_id, mid.database_id) 
        + '_' 
        + REPLACE(REPLACE(ISNULL(mid.equality_columns,''),', ','_'),'[','')
        + CASE WHEN mid.inequality_columns IS NOT NULL 
               THEN '_' + REPLACE(REPLACE(mid.inequality_columns,', ','_'),'[','') 
               ELSE '' END
        + '] ON [' + DB_NAME(mid.database_id) + '].[' 
        + SCHEMA_NAME(o.schema_id) + '].[' 
        + OBJECT_NAME(mid.object_id, mid.database_id) + '] (' 
        + ISNULL(mid.equality_columns,'') 
        + CASE WHEN mid.inequality_columns IS NOT NULL 
               THEN CASE WHEN mid.equality_columns IS NOT NULL THEN ',' ELSE '' END 
                    + mid.inequality_columns 
               ELSE '' END
        + ') ' 
        + CASE WHEN mid.included_columns IS NOT NULL 
               THEN 'INCLUDE (' + mid.included_columns + ')' 
               ELSE '' END
    AS CreateIndexStatement
FROM sys.dm_db_missing_index_group_stats AS migs
JOIN sys.dm_db_missing_index_groups AS mig
    ON migs.group_handle = mig.index_group_handle
JOIN sys.dm_db_missing_index_details AS mid
    ON mig.index_handle = mid.index_handle
JOIN sys.objects o
    ON mid.object_id = o.object_id
WHERE mid.database_id = DB_ID()
  AND migs.user_seeks > 2000
  AND CAST(migs.avg_user_impact AS INT) > 90
ORDER BY OBJECT_NAME(mid.object_id, mid.database_id);