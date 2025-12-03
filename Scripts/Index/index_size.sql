USE thyrocare;
GO

-- CTE or inline join to correlate both index and table names
SELECT 
    DB_NAME() AS DatabaseName,
    t.name AS ObjectName,
    i.name AS IndexName,
    SUM(a.used_pages) * 8 / 1024.0 AS IndexSize_MB

FROM 
    sys.indexes i
INNER JOIN 
    sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
INNER JOIN 
    sys.allocation_units a ON p.partition_id = a.container_id
INNER JOIN 
    sys.tables t ON i.object_id = t.object_id
INNER JOIN 
    [DBADB].[dbo].[UnusedIndexes] u
    ON i.name = u.IndexName AND t.name = u.ObjectName AND u.DatabaseName = 'thyrocare'
WHERE 
    u.logdate > '2025-07-28'
    AND u.TableRows > 5000 
GROUP BY 
    t.name, i.name
	having (SUM(a.used_pages) * 8 / 1024.0 )>500
ORDER BY 
    IndexSize_MB DESC;
