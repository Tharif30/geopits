SELECT 
    i.name AS IndexName,
    s.user_seeks,
    s.user_scans,
    s.user_lookups,
    s.user_updates,
    p.rows
FROM sys.dm_db_index_usage_stats s
JOIN sys.indexes i
    ON s.object_id = i.object_id AND s.index_id = i.index_id
JOIN sys.partitions p
    ON i.object_id = p.object_id AND i.index_id = p.index_id
WHERE i.object_id = OBJECT_ID('dbo.Transaction_PaymentStatus')--table name
ORDER BY (s.user_seeks + s.user_scans + s.user_lookups) DESC;
