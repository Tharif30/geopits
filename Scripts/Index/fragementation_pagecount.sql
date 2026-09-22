SELECT S.name as 'Schema', 
T.name as 'Table', 
I.name as 'Index', 
DDIPS.avg_fragmentation_in_percent, 
DDIPS.page_count 
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS DDIPS 
INNER JOIN sys.tables T on T.object_id = DDIPS.object_id 
INNER JOIN sys.schemas S on T.schema_id = S.schema_id 
INNER JOIN sys.indexes I ON I.object_id = DDIPS.object_id 
AND DDIPS.index_id = I.index_id 
WHERE DDIPS.database_id = DB_ID() 
and I.name is not null --AND DDIPS.avg_fragmentation_in_percent > 0 
ORDER BY t.name asc; 

--fragementation for particular tablesSELECT
    S.name AS [Schema],
    T.name AS [Table],
    I.name AS [Index],
    DDIPS.index_type_desc,
    DDIPS.avg_fragmentation_in_percent,
    DDIPS.page_count
FROM sys.dm_db_index_physical_stats
(
    DB_ID(),
    NULL,
    NULL,
    NULL,
    NULL
) AS DDIPS
INNER JOIN sys.tables AS T
    ON T.object_id = DDIPS.object_id
INNER JOIN sys.schemas AS S
    ON T.schema_id = S.schema_id
INNER JOIN sys.indexes AS I
    ON I.object_id = DDIPS.object_id
    AND I.index_id = DDIPS.index_id
WHERE DDIPS.database_id = DB_ID()
  AND T.name IN
  (
      'DPR_INS_MATM_VOUCHING_DATA',
      'DPR_INS_AEPS_VOUCHING_DATA_PUR',
      'DPR_AEPS_IRF_REPORT_SETTLED_DATA_WORK',
      'DPR_USERGENERATE_CSV_REPORT',
      'DPR_INS_AEPS_REFUND_REPORT'
  )
  AND I.name IS NOT NULL
ORDER BY
    T.name ASC,
    DDIPS.avg_fragmentation_in_percent DESC;
	
	
--fragementation with size
SELECT
    S.name AS [Schema],
    T.name AS [Table],
    I.name AS [Index],
    DDIPS.index_type_desc,
    DDIPS.avg_fragmentation_in_percent,
    DDIPS.page_count,
    CAST(DDIPS.page_count * 8.0 / 1024 AS DECIMAL(18,2)) AS [Size_MB],
    CAST(DDIPS.page_count * 8.0 / 1024 / 1024 AS DECIMAL(18,2)) AS [Size_GB]
FROM sys.dm_db_index_physical_stats
(
    DB_ID(),
    NULL,
    NULL,
    NULL,
    'LIMITED'
) AS DDIPS
INNER JOIN sys.tables AS T
    ON T.object_id = DDIPS.object_id
INNER JOIN sys.schemas AS S
    ON T.schema_id = S.schema_id
INNER JOIN sys.indexes AS I
    ON I.object_id = DDIPS.object_id
    AND I.index_id = DDIPS.index_id
WHERE DDIPS.database_id = DB_ID()
  AND T.name IN
  (
      'DPR_INS_MATM_VOUCHING_DATA',
      'DPR_INS_AEPS_VOUCHING_DATA_PUR',
      'DPR_AEPS_IRF_REPORT_SETTLED_DATA_WORK',
      'DPR_USERGENERATE_CSV_REPORT',
      'DPR_INS_AEPS_REFUND_REPORT'
  )
  AND I.name IS NOT NULL
ORDER BY
    T.name ASC,
    [Size_MB] DESC;