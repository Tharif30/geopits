-- Longest-running transactions
SELECT
    s.session_id,
    s.login_name,
    s.status,
    t.database_id,
    t.database_transaction_begin_time,
    DATEDIFF(SECOND, t.database_transaction_begin_time, GETDATE()) AS RunningSeconds,
    DATEDIFF(MINUTE, t.database_transaction_begin_time, GETDATE()) AS RunningMinutes,
    r.command,
    qt.text AS QueryText
FROM sys.dm_tran_database_transactions t
JOIN sys.dm_tran_session_transactions st
    ON t.transaction_id = st.transaction_id
JOIN sys.dm_exec_sessions s
    ON st.session_id = s.session_id
LEFT JOIN sys.dm_exec_requests r
    ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) qt
ORDER BY RunningSeconds DESC;
