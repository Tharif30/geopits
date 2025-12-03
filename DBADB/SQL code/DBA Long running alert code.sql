-------------------------------Table Creation Query-------

USE [DBADB]
GO
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[longqrydetails](
	[InstanceName] [nvarchar](max) NULL,
	[StartTime] [datetime] NULL,
	[ElapsedTime] [varchar](8) NULL,
	[SPID] [int] NULL,
	[UserName] [nvarchar](max) NULL,
	[ProgramName] [nvarchar](max) NULL,
	[DatabaseName] [nvarchar](max) NULL,
	[ExecutingSQL] [nvarchar](max) NULL,
	[WaitType] [nvarchar](max) NULL,
	[logdate] [datetime] NULL,
	[StatementText] [nvarchar](max) NULL,
	[StoredProcedure] [nvarchar](255) NULL,
	[is_closed] [int] NULL
) ON [PRIMARY] 
GO

ALTER TABLE [dbo].[longqrydetails] ADD  DEFAULT (getdate()) FOR [logdate]
GO

ALTER TABLE [dbo].[longqrydetails] ADD  DEFAULT ((0)) FOR [is_closed]
GO


--------------------------------------- Long running Stored procedure open code--------------------------

USE [DBADB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE proc [dbo].[DBA_GeoPITS_Longrunning]
(
    @Subject NVARCHAR(256),
    @profile_name NVARCHAR(128),
    @recipients NVARCHAR(MAX),
    @copy_recipients NVARCHAR(MAX) ,
    @ServerName NVARCHAR(128) 
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Step 1: Insert long-running queries into the table
    INSERT INTO dbadb..longqrydetails (InstanceName, SPID, StartTime, ElapsedTime, UserName, ProgramName, DatabaseName, ExecutingSQL, StatementText, WaitType, StoredProcedure)
    SELECT 
        @ServerName AS InstanceName,
        r.session_id AS SPID,
        r.start_time AS StartTime,
        CONVERT(VARCHAR, DATEADD(ms, r.total_elapsed_time, 0), 8) AS ElapsedTime,
        c.login_name AS UserName,
        c.program_name AS ProgramName,
        DB_NAME(r.database_id) AS DatabaseName,
        t.[text] AS ExecutingSQL,
        SUBSTRING(
            t.TEXT, 
            r.statement_start_offset / 2 + 1, 
            (CASE 
                WHEN r.statement_end_offset = -1 
                    THEN LEN(CONVERT(NVARCHAR(max), t.TEXT)) * 2 
                ELSE r.statement_end_offset 
             END - r.statement_start_offset) / 2 + 1
        ) AS statement_text,
        r.wait_type AS WaitType,
        COALESCE(QUOTENAME(DB_NAME(t.dbid)) + N'.' + QUOTENAME(OBJECT_SCHEMA_NAME(t.objectid, t.dbid)) + N'.' + 
         QUOTENAME(OBJECT_NAME(t.objectid, t.dbid)), 'Query') AS StoredProcedure
    FROM 
        sys.dm_exec_requests r
        INNER JOIN sys.dm_exec_sessions c ON r.session_id = c.session_id
        CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
    WHERE (r.wait_type NOT LIKE 'SP_SERVER_DIAGNOSTICS%' or r.wait_type is null)
        AND r.session_id != @@SPID
        AND r.session_id > 50
        AND t.[text] <> 'null'
        AND DB_NAME(r.database_id) NOT IN ('distribution','msdb','model','master')
        AND t.[text] <> 'begin tran'
        AND t.[text] NOT LIKE '%ALTER INDEX%'
        AND t.[text] NOT LIKE 'UPDATE STATISTICS%'
        AND t.[text] NOT LIKE '%CREATE PROCEDURE sp_readrequest%'
        AND t.[text] NOT LIKE 'BACKUP%'
        AND t.[text] NOT LIKE 'SP_SERVER_DIAGNOSTICS%'
        AND r.total_elapsed_time / 1000 >= 300  -- Change the Filter queries longer than 5 minutes (300 seconds)
        AND c.status <> 'sleeping'
    ORDER BY ElapsedTime DESC;

    -- Step 2: Generate the SPID list for termination
    DECLARE @SPIDList NVARCHAR(MAX);

    -- Concatenate SPIDs into a comma-separated list
    SET @SPIDList = 
        STUFF(
            (SELECT top 5 ', ' + CAST(SPID AS NVARCHAR)
             FROM dbadb..longqrydetails 
             WHERE DATEDIFF(MINUTE, logdate, GETDATE()) < 1
               FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)')
        , 1, 2, ''); -- Remove the leading comma and space

    -- Step 3: Generate HTML content from the longqrydetails table
    DECLARE @HTML NVARCHAR(MAX);

    SET @HTML = 
        '<html>' +
        '<head>' +
        '<style>' +
        'body { font-family: Arial, sans-serif; color: #333; line-height: 1.6; }' +
        'table { width: 100%; border-collapse: collapse; margin-top: 20px; }' +
        'table, th, td { border: 1px solid #ddd; }' +
        'th, td { padding: 12px; text-align: centre; }' +
        'th { background-color: #008bff; color: white; }' +
        'tr:nth-child(even) { background-color: #f2f2f2; }' +
        'p { margin: 0 0 10px; }' +
        'h2 { color: #007bff; }' +
        '</style>' +
        '</head>' +
        '<body>' +
        '<p>Hello Team,</p>' +
        '<p>Our DBAs have detected long-running queries on <b>' + @ServerName + '</b> Server that are consuming significant resources and may impact overall performance.</p>' +
        '<p>Below is a query that requires your attention:</p>' +
        '<p> SPID:<strong>' + ISNULL(@SPIDList, 'No SPIDs available') + '</strong></p>' +
        '<p> Query Details:</p>' +
        '<table>' +
        '<thead>' +
        '<tr>' +
        '<th>SPID</th>' +
        '<th>Start Time</th>' +
        '<th>Elapsed Time (hh:mm:ss)</th>' +
        '<th>User</th>' +
        '<th>Database</th>' +
        '<th>SQL Text</th>' +
        '<th>Wait Type</th>' +
        '<th>StoredProcedure</th>' +
        '</tr>' +
        '</thead>' +
        '<tbody>' +
        (SELECT TOP 5
            '<tr>' +
            '<td>' + ISNULL(CAST(SPID AS NVARCHAR(MAX)), '') + '</td>' +
            '<td>' + ISNULL(CONVERT(varchar, StartTime, 120), '') + '</td>' +
            '<td>' + ISNULL(ElapsedTime, '') + '</td>' +
            '<td>' + ISNULL(UserName, '') + '</td>' +
            '<td>' + ISNULL(DatabaseName, '') + '</td>' +
            '<td>' + ISNULL(LEFT(StatementText, 250), '') + '</td>' +
            '<td>' + ISNULL(WaitType, '') + '</td>' +
            '<td>' + ISNULL(StoredProcedure, 'Query') + '</td>' +
            '</tr>'
        FROM dbadb..longqrydetails 
        WHERE DATEDIFF(MINUTE, logdate, GETDATE()) < 1
        ORDER BY ElapsedTime DESC
        FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)') +
        '</tbody>' +
        '</table>' +
        '<p>    </p>' +
        '<p> This query has been running for over 5 minutes. We recommend terminating it to avoid potential performance issues.<br> Please confirm if you would like us to proceed with terminating the query, or if you prefer to allow it to complete its execution  </p>' +
        '<p>Kindly provide your confirmation, and our team will take the necessary action based on your response.</p>' +
        '<p>Thanks for your attention.</p>' +
        '<p>Best Regards,<br>MSSQL DBA<br>GeoPITS</p>' + --Change
        '</body>' +
        '</html>';

    -- Output the final HTML
    --SELECT @HTML AS HTML;

    IF (@HTML IS NOT NULL)
    BEGIN
        EXEC msdb.dbo.Sp_send_dbmail
            @profile_name = @profile_name,
            @body = @HTML,
            @body_format = 'html',
            @recipients = @recipients,
            @copy_recipients = @copy_recipients,
            @subject = @Subject;
    END

    SET NOCOUNT OFF;
END

SET ANSI_NULLS OFF
GO

------------------------------------------------------------------------------------------

--Open Long running SP code 
-------------------------------------------------------------------------------------------
DECLARE @subjectcontent NVARCHAR(512);
DECLARE @Servername NVARCHAR(512);

SET @Servername = @@SERVERNAME;
SET @subjectcontent =  'Client ' +  @ServerName + ' - Long Running Queries: Open';

EXEC [dbo].[DBA_GeoPITS_Longrunning]

    @Subject =@subjectcontent ,
    @profile_name = 'MAILPROFILE',
    @recipients = 'MAILID@Domain.com',
    @copy_recipients = '',
    @ServerName =@Servername ;


-------------------------------------------------------------------------------------------
--          Closed Long running queries SP code
-------------------------------------------------------------------------------------------
USE [DBADB]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create proc [dbo].[DBA_GeoPITS_Longrunning_closed]
(
    @Subject NVARCHAR(256),
    @profile_name NVARCHAR(128),
    @recipients NVARCHAR(MAX),
    @copy_recipients NVARCHAR(MAX),
    @ServerName NVARCHAR(128)
)
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #longqrydetails(
	[InstanceName] [nvarchar](max) NULL,
	[StartTime] [datetime] NULL,
	[ElapsedTime] [varchar](8) NULL,
	[SPID] [int] NULL,
	[UserName] [nvarchar](max) NULL,
	[ProgramName] [nvarchar](max) NULL,
	[DatabaseName] [nvarchar](max) NULL,
	[ExecutingSQL] [nvarchar](max) NULL,
	[WaitType] [nvarchar](max) NULL,
	[logdate] [datetime] NULL DEFAULT (getdate())
) ;


    INSERT INTO #longqrydetails (InstanceName, SPID, StartTime, ElapsedTime, UserName, ProgramName, DatabaseName, ExecutingSQL, WaitType)
    SELECT 
        @@ServerName AS InstanceName,
        r.session_id AS SPID,
        r.start_time AS StartTime,
        CONVERT(VARCHAR, DATEADD(ms, r.total_elapsed_time, 0), 8) AS ElapsedTime,
        c.login_name AS UserName,
        c.program_name AS ProgramName,
        DB_NAME(r.database_id) AS DatabaseName,
        LEFT(t.[text], 500) AS ExecutingSQL,
        r.wait_type AS WaitType
    FROM 
        sys.dm_exec_requests r
        INNER JOIN sys.dm_exec_sessions c ON r.session_id = c.session_id
        CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
    WHERE  (r.wait_type NOT LIKE 'SP_SERVER_DIAGNOSTICS%' or r.wait_type is null)
        AND r.session_id != @@SPID
        AND r.session_id > 50
        AND t.[text] <> 'null'
        AND DB_NAME(r.database_id) NOT IN ('distribution','msdb','model','master')
        AND t.[text] <> 'begin tran'
        AND t.[text] NOT LIKE '%ALTER INDEX%'
        AND t.[text] NOT LIKE 'UPDATE STATISTICS%'
        AND t.[text] NOT LIKE '%CREATE PROCEDURE sp_readrequest%'
        AND t.[text] NOT LIKE 'BACKUP%'
        AND r.total_elapsed_time / 1000 >= 300  -- Filter queries longer than 5 minutes (300 seconds)
        AND c.status <> 'sleeping'
    ORDER BY ElapsedTime DESC;

    -- Step 3: Generate the SPID list for termination
    DECLARE @SPIDList NVARCHAR(MAX);

    SET @SPIDList = 
       STUFF((SELECT ', ' + CAST(SPID AS NVARCHAR)
              FROM dbadb..longqrydetails  
              WHERE DATEDIFF(MINUTE, logdate, GETDATE()) <= 25 
                AND SPID NOT IN (SELECT SPID FROM #longqrydetails) 
                AND is_closed = 0 
              GROUP BY SPID
              FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)')
        , 1, 2, ''); -- Remove the leading comma and space

    -- Step 4: Generate HTML content from the temporary table
    DECLARE @HTML NVARCHAR(MAX);

    SET @HTML = 
        '<html>' +
        '<head>' +
        '<style>' +
        'body { font-family: Arial, sans-serif; color: #333; line-height: 1.6; }' +
        'table { width: 100%; border-collapse: collapse; margin-top: 20px; }' +
        'table, th, td { border: 1px solid #ddd; }' +
        'th, td { padding: 12px; text-align: left; }' +
        'th { background-color: #4169E1; color: #C0C0C0; }' +
        '</style>' +
        '</head>' +
        '<body>' +
        '<p>Hello Team,</p>' +
        '<p>We have recently identified and reviewed several long-running queries on <b>' + @ServerName + '</b> that were consuming substantial resources.</p>' +
        '<p> I wanted to provide you with an update on the status of these queries.</p>' +
        '<p>Below is a summary of the long-running queries that have been addressed:</p>' +
        '<p>The following queries have either been executed successfully or terminated:</p>' +
        '<p> Query ID: <b>' + ISNULL(@SPIDList, 'No SPIDs available') + '</b> .</p>' +
        '<p>These actions were taken as part of our ongoing performance optimization efforts, and the corresponding SPIDs have been closed.</p>' +
        '<p>  Details of Closed Queries:</p>' +
        '<table>' +
        '<tr>' +
        '<th>SPID</th>' +
        '<th>Start Time</th>' +
        '<th>Elapsed Time (hh:mm:ss)</th>' +
        '<th>User</th>' +
        '<th>Database</th>' +
        '<th>SQL Text</th>' +
        '<th>Wait Type</th>' +
        '<th>StoredProcedure</th>' +
        '</tr>' +
        '</thead>' +
        '<tbody>' +
        (SELECT 
            '<tr>' +
            '<td>' + ISNULL(CAST(SPID AS NVARCHAR(MAX)), '') + '</td>' +
            '<td>' + ISNULL(CONVERT(varchar, StartTime, 120), '') + '</td>' +
            '<td>' + ISNULL(MAX(ElapsedTime), '') + '</td>' +
            '<td>' + ISNULL(UserName, '') + '</td>' +
            '<td>' + ISNULL(DatabaseName, '') + '</td>' +
            '<td>' + ISNULL(LEFT(StatementText, 250), '') + '</td>' +
            '<td>' + ISNULL(WaitType, '') + '</td>' +
            '<td>' + ISNULL(StoredProcedure, 'Query') + '</td>' +
            '</tr>'
        FROM dbadb..longqrydetails 
        WHERE DATEDIFF(MINUTE, logdate, GETDATE()) <= 25 
          AND SPID NOT IN (SELECT SPID FROM #longqrydetails) 
          AND is_closed = 0 
        GROUP BY SPID, StartTime, UserName, DatabaseName, LEFT(StatementText, 250), WaitType, StoredProcedure
        FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)') +
        '</table>' +
        '<p>Thanks for your consideration.</p>' +
        '<p>Best regards,<br>MSSQL DBA,<br/>GeoPITS</p>' +
        '</body>' +
        '</html>';

    UPDATE dbadb..longqrydetails 
    SET is_closed = 1  
    WHERE DATEDIFF(MINUTE, logdate, GETDATE()) <= 25 
      AND SPID NOT IN (SELECT SPID FROM #longqrydetails) 
      AND is_closed = 0;

    DROP TABLE #longqrydetails;

    -- Output the final HTML
    --SELECT @HTML AS HTML;
    IF (@HTML IS NOT NULL)
    BEGIN
        EXEC msdb.dbo.Sp_send_dbmail
            @profile_name = @profile_name,
            @body = @HTML,
            @body_format = 'html',
            @recipients = @recipients,
            @copy_recipients = @copy_recipients,
            @blind_copy_recipients = '',
            @subject = @Subject;
    END

    SET NOCOUNT OFF;
END

SET ANSI_NULLS OFF
--------------------------------------------------------------------------------------------------------------------------------------------------------

--                           Closed SP execute script
--------------------------------------------------------------------------------------------------------------------------------------------------------


DECLARE @subjectcontent NVARCHAR(512);
DECLARE @Servername NVARCHAR(512);

SET @Servername = @@SERVERNAME;
SET @subjectcontent =  'Client ' +  @ServerName + ' - Long Running Queries: Closed';

EXEC [dbo].[DBA_GeoPITS_Longrunning_closed]

    @Subject =@subjectcontent ,
    @profile_name = 'MAILPROFILE',
    @recipients = 'MAILID@Domain.com',
    @copy_recipients = '',
    @ServerName =@Servername ;

--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
