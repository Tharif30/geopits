--query store enabled then works
SELECT  
    CAST(rsi.end_time AS DATE) AS [ExecutionDate],
    SUM(rs.count_executions) AS [TotalExecutions]
FROM sys.query_store_runtime_stats rs
JOIN sys.query_store_runtime_stats_interval rsi 
    ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
WHERE rsi.end_time >= DATEADD(MONTH, -1, GETDATE())
GROUP BY CAST(rsi.end_time AS DATE)
ORDER BY [ExecutionDate] DESC;