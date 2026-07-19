--Query Insights logical_reads
SELECT TOP 5
    DB_NAME(st.dbid) AS [Database Name],
    OBJECT_NAME(st.objectid, st.dbid) AS [Object Name],
 LEFT(
    REPLACE(REPLACE(
        SUBSTRING(
            st.text,
            (qs.statement_start_offset / 2) + 1,
            (
                (CASE 
                    WHEN qs.statement_end_offset = -1 
                    THEN DATALENGTH(st.text)
                    ELSE qs.statement_end_offset 
                END - qs.statement_start_offset
                ) / 2
            ) + 1
        ),
    CHAR(13), ' '),
CHAR(10), ' ')
,500) AS [Query SQL Text],

    qs.total_logical_reads AS [Total Logical Reads (Pages)],

    (qs.total_logical_reads * 8) AS [Total Logical Reads (KB)],

    (qs.total_logical_reads * 8.0 / 1024) AS [Total Logical Reads (MB)],

    qs.execution_count AS [Execution Count]

FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE DB_NAME(st.dbid) NOT IN
(
    'master','model','msdb',
    'DBADB','ReportServer','ReportServerTempDB'
)
ORDER BY qs.total_logical_reads DESC;

--Query Insights logical_reads
--query_insights_by_cpu_time
SELECT TOP 5
    DB_NAME(st.dbid) AS [Database Name],
    OBJECT_NAME(st.objectid, st.dbid) AS [Object Name],
    SUBSTRING(st.text,
        (qs.statement_start_offset/2) + 1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset)/2) + 1
    ) AS [Query SQL Text],
    qs.total_worker_time / 1000 AS [Total CPU Time (ms)],
    qs.execution_count
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE DB_NAME(st.dbid) NOT IN
(
    'master','model','msdb',
    'DBADB','ReportServer','ReportServerTempDB'
)
ORDER BY qs.total_worker_time DESC;
