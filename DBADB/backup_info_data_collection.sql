DECLARE @cols NVARCHAR(MAX) = '';
DECLARE @query NVARCHAR(MAX);
DECLARE @html NVARCHAR(MAX);

-- Build list of last 7 dates as column headers
SELECT @cols = STRING_AGG(QUOTENAME(CONVERT(VARCHAR(10), theDate, 23)), ',')
FROM (
    SELECT CAST(DATEADD(DAY, -v.number, CAST(GETDATE() AS DATE)) AS DATE) AS theDate
    FROM master.dbo.spt_values v
    WHERE v.type='P' AND v.number BETWEEN 0 AND 6
) d;

-- Build dynamic query (pivot only)
SET @query = N'
;WITH Calendar AS
(
    SELECT CAST(DATEADD(DAY, -v.number, CAST(GETDATE() AS DATE)) AS DATE) AS theDate
    FROM master.dbo.spt_values v
    WHERE v.type=''P'' AND v.number BETWEEN 0 AND 6
)
, BackupData AS
(
    SELECT  
          B.DBNmae AS database_name,
          CASE B.backupType
              WHEN ''Database'' THEN ''Full''
              WHEN ''DIFF'' THEN ''Differential''
              WHEN ''Log'' THEN ''Transaction Log''
              ELSE B.backupType
          END AS backup_type,
          CAST(B.BackupEndTime AS DATE) AS backup_date,
          ''Succeeded'' AS status
    FROM [DBADB].[dbo].[BackupInfoData] B
    WHERE B.BackupEndTime >= (SELECT MIN(theDate) FROM Calendar)
      AND B.DBNmae IN (''production_db_1'') 
      AND B.backupType IS NOT NULL
)
, WithNotRun AS
(
    SELECT DISTINCT 
           d.DBNmae AS database_name,
           bt.backup_type,
           cal.theDate AS backup_date,
           ISNULL(bd.status, ''Not Run'') AS status
    FROM (VALUES (''Full''),(''Differential''),(''Transaction Log'')) bt(backup_type)
    CROSS JOIN Calendar cal
    CROSS JOIN (
        SELECT DISTINCT DBNmae 
        FROM [DBADB].[dbo].[BackupInfoData]
        WHERE DBNmae IN (''production_db_1'') 
          AND backupType IS NOT NULL
    ) d
    LEFT JOIN BackupData bd
        ON bd.database_name = d.DBNmae
        AND bd.backup_type = bt.backup_type
        AND bd.backup_date = cal.theDate
)
SELECT backup_type, database_name, ' + @cols + '
FROM
(
    SELECT backup_type, database_name, backup_date, status
    FROM WithNotRun
) src
PIVOT
(
    MAX(status) FOR backup_date IN (' + @cols + ')
) p
ORDER BY database_name, backup_type;';

-- Store results
IF OBJECT_ID('tempdb..#Results') IS NOT NULL DROP TABLE #Results;
CREATE TABLE #Results (
    backup_type NVARCHAR(50),
    database_name NVARCHAR(255),
    d1 NVARCHAR(50),
    d2 NVARCHAR(50),
    d3 NVARCHAR(50),
    d4 NVARCHAR(50),
    d5 NVARCHAR(50),
    d6 NVARCHAR(50),
    d7 NVARCHAR(50)
);

INSERT INTO #Results
EXEC sp_executesql @query;

-- Build header dynamically
DECLARE @header NVARCHAR(MAX);
SELECT @header = 
    '<tr><th>Backup Type</th><th>Database Name</th>' +
    STRING_AGG('<th>' + CONVERT(VARCHAR(10), theDate, 23) + '</th>', '')
FROM (
    SELECT CAST(DATEADD(DAY, -v.number, CAST(GETDATE() AS DATE)) AS DATE) AS theDate
    FROM master.dbo.spt_values v
    WHERE v.type='P' AND v.number BETWEEN 0 AND 6
) d;

-- Build body rows
DECLARE @body NVARCHAR(MAX) = '';
SELECT @body = COALESCE(@body, '') +
    '<tr><td>' + ISNULL(backup_type,'') + '</td><td>' + ISNULL(database_name,'') + '</td>' +
    '<td>' + ISNULL(d1,'') + '</td>' +
    '<td>' + ISNULL(d2,'') + '</td>' +
    '<td>' + ISNULL(d3,'') + '</td>' +
    '<td>' + ISNULL(d4,'') + '</td>' +
    '<td>' + ISNULL(d5,'') + '</td>' +
    '<td>' + ISNULL(d6,'') + '</td>' +
    '<td>' + ISNULL(d7,'') + '</td></tr>'
FROM #Results;

-- Final HTML
SET @html = 
N'<html>
<head>
<style>
table {border-collapse:collapse; width:100%; font-family:Arial;}
th {background-color:#1E90FF; color:white; padding:5px; border:1px solid black;}
td {padding:5px; border:1px solid black; color:black; text-align:center;}
</style>
</head>
<body>
<h3>Backup Status Report (Last 7 Days)</h3>
<table>' + @header + @body + '</table>
</body>
</html>';

-- Send Email
EXEC msdb.dbo.sp_send_dbmail
    @profile_name = 'dba',   -- Change
    @recipients = 'mohamed@geopits.com',  -- Change
    @subject = 'SQL Backup Status Report',
    @body = @html,
    @body_format = 'HTML';

DROP TABLE #Results;


--------------------------------------------------------------------------------
-- Backupinfo table
--------------------------------------------------------------------------------
--USE [DBADB]
--GO


--SET ANSI_NULLS ON
--GO

--SET QUOTED_IDENTIFIER ON
--GO

--CREATE TABLE [dbo].[BackupInfoData](
--	[Servername] [varchar](50) NULL,
--	[DBNmae] [varchar](70) NULL,
--	[BackupStartDate] [datetime] NULL,
--	[BackupEndTime] [datetime] NULL,
--	[ExpDate] [datetime] NULL,
--	[backupType] [varchar](50) NULL,
--	[BackupSize] [bigint] NULL,
--	[PhysicalDeviceName] [varchar](max) NULL,
--	[backupName] [varchar](255) NULL,
--	[description] [varchar](255) NULL
--) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
--GO
