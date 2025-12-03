
--top memory consuming queries sql server 2014
SELECT TOP 20
    DB_NAME(qt.dbid) AS DatabaseName,
    OBJECT_NAME(qt.objectid, qt.dbid) AS ProcedureName,  -- procedure/function/view name
    qs.execution_count,
    qs.total_worker_time / 1000 AS TotalCPU_ms,
    qs.total_logical_reads AS TotalLogicalReads,
    qs.total_elapsed_time / 1000 AS TotalElapsedTime_ms,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(qt.text)
            ELSE qs.statement_end_offset END
          - qs.statement_start_offset)/2) + 1) AS QueryText,
    qp.query_plan
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
WHERE qt.dbid NOT IN (1,2,3,4)   
AND  qs.execution_count>10
AND DB_NAME(qt.dbid)='Nueclear'-- exclude system databases
ORDER BY qs.total_worker_time DESC;
