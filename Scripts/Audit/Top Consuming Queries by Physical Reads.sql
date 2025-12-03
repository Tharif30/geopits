--Top Consuming Queries by Physical Reads
SELECT TOP 10
    qs.total_physical_reads AS TotalPhysicalReads,
    qs.execution_count,
    qs.total_physical_reads / qs.execution_count AS AvgPhysicalReads,
    qs.total_elapsed_time / qs.execution_count AS AvgElapsedTime,
    qs.total_worker_time / qs.execution_count AS AvgCPU,
    SUBSTRING(qt.text, (qs.statement_start_offset / 2) + 1,
              ((CASE qs.statement_end_offset 
                    WHEN -1 THEN DATALENGTH(qt.text)
                    ELSE qs.statement_end_offset 
                END - qs.statement_start_offset) / 2) + 1) AS QueryText,
    qp.query_plan
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY qs.total_physical_reads DESC;
