--Unused Index

SELECT  
    OBJECT_SCHEMA_NAME(i.object_id) + '.' + OBJECT_NAME(i.object_id) AS Table_Name,
    i.name AS Index_Name,
    ius.user_seeks AS UserSeeks,
    ius.user_scans AS UserScans,
    ius.user_updates AS UserUpdates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats ius 
    ON i.index_id = ius.index_id 
    AND i.object_id = ius.object_id
    AND ius.database_id = DB_ID()
WHERE i.type_desc <> 'HEAP' -- Only include indexes (not heaps)
  AND OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
  AND (
        ISNULL(ius.user_seeks, 0) = 0 AND 
        ISNULL(ius.user_scans, 0) = 0 AND 
        ISNULL(ius.user_lookups, 0) = 0
      )
ORDER BY ius.user_updates DESC;
