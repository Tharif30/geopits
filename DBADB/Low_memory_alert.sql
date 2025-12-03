--------------------------------------------------------------------------
-- SQL Server Memory Alert
--------------------------------------------------------------------------
--Table create code.
--USE [DBADB]
--GO

--SET ANSI_NULLS ON
--GO

--SET QUOTED_IDENTIFIER ON
--GO

--CREATE TABLE [dbo].[MemoryUtilisationdata](
--	[Datetime] [datetime] NULL,
--	[SQL_current_Memory_usage_Gb] [int] NULL,
--	[SQL_Max_Memory_target_Gb] [int] NULL,
--	[OS_Total_Memory_Gb] [int] NULL,
--	[OS_Available_Memory_Gb] [int] NULL
--) ON [PRIMARY]
--GO


--------------------------------------------------------------------------
--Job step code

USE master;
GO

INSERT INTO [DBADB].[dbo].[MemoryUtilisationdata]
SELECT 
    GETDATE(),
    SQL_current_Memory_usage_mb/1024.0 AS [SQL_current_Memory_usage_Gb],
    SQL_Max_Memory_target_mb/1024.0 AS [SQL_Max_Memory_target_Gb], 
    OS_Total_Memory_mb/1024.0 AS [OS_Total_Memory_Gb],
    OS_Available_Memory_mb/1024.0 AS [OS_Available_Memory_Gb] 
FROM fn_checkSQLMemory();
GO

---------------------------------------------------------------------------
-- Alert job step
SET NOCOUNT ON;

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

DECLARE 
    @profile       NVARCHAR(100) = N'DBA',
    @recipient     NVARCHAR(MAX)   = N'mssqlalerts@geopits.com',
    @cc            NVARCHAR(MAX)   = N'',
    @bcc           NVARCHAR(MAX)   = N'mohamed@geopits.com',
    @body          NVARCHAR(MAX),
    @sub           NVARCHAR(200),
    @MinAvailableGB INT             = 10;  -- change threshold here

SET @sub = N'THYROCARE Memory Alert on ' 
         + CAST(@@SERVERNAME AS NVARCHAR(128)) 
         + N': ' + CONVERT(NVARCHAR(30), GETDATE(), 107);

-- Prepare last 5 rows (most recent)
IF OBJECT_ID('tempdb..#LastFive') IS NOT NULL DROP TABLE #LastFive;
SELECT TOP (5)
    [Datetime],
    SQL_current_Memory_usage_Gb,
    SQL_Max_Memory_target_Gb,
    OS_Total_Memory_Gb,
    OS_Available_Memory_Gb
INTO #LastFive
FROM DBADB.dbo.MemoryUtilisationdata
ORDER BY [Datetime] DESC;

-- how many are below threshold?
DECLARE @LowCount INT;
SELECT @LowCount = COUNT(*) FROM #LastFive WHERE OS_Available_Memory_Gb < @MinAvailableGB;

-- proceed only if all last 5 are below threshold
IF @LowCount = 5
BEGIN
    -- build HTML rows using STRING_AGG (preserves order with WITHIN GROUP)
    DECLARE @rows NVARCHAR(MAX);


    SELECT @rows = 
        STUFF((
            SELECT 
                N'<tr>' +
                    N'<td>' + CONVERT(NVARCHAR(19), [Datetime], 120) + N'</td>' +
                    N'<td>' + ISNULL(CAST(SQL_current_Memory_usage_Gb AS NVARCHAR(20)), N'') + N'</td>' +
                    N'<td>' + ISNULL(CAST(SQL_Max_Memory_target_Gb AS NVARCHAR(20)), N'') + N'</td>' +
                    N'<td>' + ISNULL(CAST(OS_Total_Memory_Gb AS NVARCHAR(20)), N'') + N'</td>' +
                    N'<td>' + ISNULL(CAST(OS_Available_Memory_Gb AS NVARCHAR(20)), N'') + N'</td>' +
                N'</tr>'
            FROM #LastFive
            ORDER BY [Datetime]
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 0, N'');

    IF @rows IS NULL
        SET @rows = N'<tr><td colspan="5">No records found</td></tr>';

    -- compose body
    SET @body = 
    N'<html>
        <head>
            <style>
                table, th, td { border: 1px solid black; border-collapse: collapse; text-align: center; padding: 5px; }
            </style>
        </head>
        <body>
            <h2>Low Memory Alert: ' + CAST(@@SERVERNAME AS NVARCHAR(128)) + N'</h2>
            <p>Last 5 occurrences all show low memory (&lt;' + CAST(@MinAvailableGB AS NVARCHAR(10)) + N' GB available):</p>
            <table>
                <tr>
                    <th>Date time</th>
                    <th>SQL Memory usage (GB)</th>
                    <th>SQL Max Memory (GB)</th>
                    <th>OS Total Memory (GB)</th>
                    <th>OS Available Memory (GB)</th>
                </tr>'
                + @rows +
            N'</table>
        </body>
    </html>';

    -- send email
    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = @profile,
        @recipients = @recipient,
        @copy_recipients = @cc,
        @blind_copy_recipients = @bcc,
        @subject = @sub,
        @body = @body,
        @body_format = N'HTML';
END

DROP TABLE #LastFive;
SET NOCOUNT OFF;
GO
