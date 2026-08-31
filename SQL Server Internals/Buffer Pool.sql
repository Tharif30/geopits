--database page count in buffer pool
SELECT
    OBJECT_NAME(p.object_id) AS table_name,
    COUNT(*) AS pages_in_buffer_pool
FROM sys.dm_os_buffer_descriptors AS bd
JOIN sys.allocation_units AS au
    ON bd.allocation_unit_id = au.allocation_unit_id
JOIN sys.partitions AS p
    ON au.container_id = p.hobt_id
WHERE bd.database_id = DB_ID()
GROUP BY p.object_id;


--particular database total pages & size in buffer pool
SELECT
    DB_NAME(database_id) AS database_name,
    COUNT(*) AS buffer_pages,
    COUNT(*) * 8 AS buffer_pool_kb
FROM sys.dm_os_buffer_descriptors
WHERE database_id = DB_ID() --database_id =12--NOT IN (1, 2, 3, 4);
GROUP BY database_id;


-- Buffer cache hit ratio
SELECT 
    [Buffer cache hit ratio] = 
    (SELECT cntr_value 
     FROM sys.dm_os_performance_counters
     WHERE counter_name = 'Buffer cache hit ratio'
       AND object_name LIKE '%Buffer Manager%');

--commnad to clear bufferpool
CHECKPOINT;
DBCC DROPCLEANBUFFERS;



--commands to extract page level information
--to find page details of a table or data
dbcc ind('DBADB',test_under,-1)

--actual page content 
DBCC TRACEON(3604)
DBCC PAGE('DBADB',1,102021,3) WITH TABLERESULTS --[0|1|2|3] display option
GO