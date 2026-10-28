USE [DBADB]
GO

/****** Object:  StoredProcedure [dbo].[usp_whatisgoingon]    Script Date: 10/28/2026 4:42:55 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE   PROCEDURE  [dbo].[usp_whatisgoingon]
AS
BEGIN
    SELECT 
        r.session_id AS SessionID,
        r.blocking_session_id AS BlockingSessionID,
        r.total_elapsed_time / 60000 AS RunningMinutes,
        r.percent_complete AS PercentComplete,
        DB_NAME(r.database_id) AS DatabaseName,
		s.host_name AS HostName,
        t.text AS StatementText,
		s.status,
        r.command AS CommandText,
		s.login_name  AS loginname,
        s.program_name AS ProgramName,
        r.cpu_time AS CPUTime,
        r.last_wait_type AS LastWaitType,
		s.login_time AS logintime
	FROM master.sys.dm_exec_requests r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
    JOIN master.sys.dm_exec_sessions s ON r.session_id = s.session_id
    ORDER BY r.total_elapsed_time / 60000 DESC;
END;
GO


