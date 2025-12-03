
SELECT
    r.session_id AS spid,
    s.login_name,
    s.host_name,
    DB_NAME(r.database_id) AS database_name,
    r.status,
    r.command,
    r.cpu_time / 1000.0 AS cpu_sec, -- CPU time in seconds
    r.total_elapsed_time / 1000.0 AS elapsed_sec, -- Duration in seconds
    r.reads,
    r.writes,
    r.logical_reads,
    r.blocking_session_id AS blocked_by,
    b.session_id AS blocking_spid,
    s.program_name,
    SUBSTRING(t.text, 
              r.statement_start_offset / 2 + 1,
              (CASE WHEN r.statement_end_offset = -1 
                    THEN LEN(CONVERT(NVARCHAR(MAX), t.text)) * 2 
                    ELSE r.statement_end_offset END - r.statement_start_offset) / 2 + 1
    ) AS current_statement,
    t.text AS full_batch
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s 
    ON r.session_id = s.session_id
LEFT JOIN sys.dm_exec_requests b
    ON r.blocking_session_id = b.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE s.is_user_process = 1 -- ignore system sessions
ORDER BY r.total_elapsed_time DESC;


