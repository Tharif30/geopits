use []
--missing index
SELECT 
    DB_NAME(mid.database_id) AS DatabaseName,
    OBJECT_NAME(mid.object_id, mid.database_id) AS TableName,
    migs.user_seeks AS UserSeeks,
    migs.last_user_seek AS LastUserSeek,
    CAST(migs.avg_user_impact AS VARCHAR(5)) + '%' AS EstimatedImprovementPercent,  -- percentage benefit
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
               THEN CASE WHEN mid.equality_columns IS NOT NULL THEN ',' ELSE '' END + mid.inequality_columns 
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
  AND migs.user_seeks > 100
ORDER BY migs.avg_user_impact DESC, UserSeeks DESC;



--unused index
SELECT
    DB_NAME(ius.database_id) AS DatabaseName,
    s.name AS SchemaName,
    t.name AS TableName,
    i.name AS IndexName,
    i.index_id,
    ius.user_updates AS UserUpdates,
    ius.user_seeks AS UserSeeks,
    ius.user_scans AS UserScans,
    ius.user_lookups AS UserLookups,
    ius.last_user_update
FROM sys.dm_db_index_usage_stats AS ius
JOIN sys.indexes AS i
    ON i.index_id = ius.index_id
   AND i.object_id = ius.object_id
JOIN sys.objects AS t
    ON i.object_id = t.object_id
JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
WHERE ius.database_id = DB_ID()
  AND i.is_primary_key = 0
  AND i.is_unique = 0
  AND t.is_ms_shipped = 0
  -- unused (0 reads)
  AND ius.user_seeks = 0
  AND ius.user_scans = 0
  AND ius.user_lookups = 0
  -- but still maintained
  AND ius.user_updates > 0
ORDER BY ius.user_updates DESC;
