--total no  of user connections
SELECT COUNT(*) AS ActiveUserConnections
FROM sys.dm_exec_sessions
WHERE is_user_process = 1;

--sessino id,login_name 
SELECT session_id, login_name, status, host_name, program_name, cpu_time, memory_usage
FROM sys.dm_exec_sessions
WHERE is_user_process = 1;

--no of connection for a database
SELECT  
    @@SERVERNAME AS Server,
    s.host_name AS HostName,
    DB_NAME(s.database_id) AS DatabaseName,
    s.program_name AS ProgramName,
    COUNT(*) AS TotalConnections
FROM sys.dm_exec_sessions s
WHERE is_user_process = 1
GROUP BY s.host_name, s.program_name, s.database_id
ORDER BY TotalConnections DESC;