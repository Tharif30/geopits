 --Page life expectancy — < 300 is bad
SELECT 
    COUNT(*) AS Bad_PageLifeExpectancy_Count
FROM [DBADB].[dbo].[PerfMonData]
WHERE [Counter] LIKE 'SQLServer:Buffer Manager:Page life expectancy%'
  AND TRY_CAST([Value] AS FLOAT) < 300;

 --Page reads/sec — Sudden spikes
SELECT 
    COUNT(*) AS Bad_PageReads_Count
FROM [DBADB].[dbo].[PerfMonData]
WHERE [Counter] LIKE 'SQLServer:Buffer Manager:Page reads/sec%'
  AND TRY_CAST([Value] AS FLOAT) > 1000;

--Page writes/sec — Spike detection
SELECT 
    COUNT(*) AS Bad_PageWrites_Count
FROM [DBADB].[dbo].[PerfMonData]
WHERE [Counter] LIKE 'SQLServer:Buffer Manager:Page writes/sec%'
  AND TRY_CAST([Value] AS FLOAT) > 500;

--Lazy writes/sec > 30
SELECT 
    COUNT(*) AS Bad_LazyWrites_Count
FROM [DBADB].[dbo].[PerfMonData]
WHERE [Counter] LIKE 'SQLServer:Buffer Manager:Lazy writes/sec%'
  AND TRY_CAST([Value] AS FLOAT) > 30;

--Free list stalls/sec > 2
SELECT 
    COUNT(*) AS Bad_FreeListStalls_Count
FROM [DBADB].[dbo].[PerfMonData]
WHERE [Counter] LIKE 'SQLServer:Buffer Manager:Free list stalls/sec%'
  AND TRY_CAST([Value] AS FLOAT) > 2;

Server Performance Degradation 
#1229290




