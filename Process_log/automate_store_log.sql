


SET ANSI_NULLS, QUOTED_IDENTIFIER ON;
GO

--CREATE TABLE ErrorLogHistory (
--    LogDate DATETIME,
--    ProcessInfo NVARCHAR(50),
--    LogText NVARCHAR(MAX),
--    LogFile NVARCHAR(50)  
--);

--truncate table ErrorLogHistory;
--truncate table LoginAuditSuccessDaily;
--truncate table LoginAuditFailedDaily;
-- Create a temporary table for the current log file
CREATE TABLE #TempCurrentLog (
    LogDate DATETIME,
    ProcessInfo NVARCHAR(50),
    LogText NVARCHAR(MAX)
);

-- Populate the temporary table with the current error log data
INSERT INTO #TempCurrentLog
EXEC sp_readerrorlog 0, 1;  -- 0 = current log

-- Insert distinct rows from the current log file into ErrorLogHistory if they don't already exist
INSERT INTO ErrorLogHistory (LogDate, ProcessInfo, LogText, LogFile)
SELECT DISTINCT T.LogDate, T.ProcessInfo, T.LogText, 'ERRORLOG'
FROM #TempCurrentLog T
WHERE NOT EXISTS (
    SELECT 1 
    FROM ErrorLogHistory E
    WHERE E.LogDate = T.LogDate
      AND E.ProcessInfo = T.ProcessInfo
      AND E.LogText = T.LogText
);

DROP TABLE #TempCurrentLog;
GO

-- Create a temporary table for the archived log file
CREATE TABLE #TempArchiveLog (
    LogDate DATETIME,
    ProcessInfo NVARCHAR(50),
    LogText NVARCHAR(MAX)
);

-- Populate the temporary table with the archived error log data
INSERT INTO #TempArchiveLog
EXEC sp_readerrorlog 1, 1;  -- 1 = archived log (ERRORLOG.1)

-- Insert distinct rows from the archived log file into ErrorLogHistory if they don't already exist
INSERT INTO ErrorLogHistory (LogDate, ProcessInfo, LogText, LogFile)
SELECT DISTINCT T.LogDate, T.ProcessInfo, T.LogText, 'ERRORLOG.1'
FROM #TempArchiveLog T
WHERE NOT EXISTS (
    SELECT 1 
    FROM ErrorLogHistory E
    WHERE E.LogDate = T.LogDate
      AND E.ProcessInfo = T.ProcessInfo
      AND E.LogText = T.LogText
);

DROP TABLE #TempArchiveLog;
GO

--successful logins
WITH ExtractedLogs AS (
    SELECT 
        LogDate AS LastLogin,
        SUBSTRING(LogText, CHARINDEX('for user ''', LogText) + 10, 
                  CHARINDEX('''. Connection', LogText) - CHARINDEX('for user ''', LogText) - 10) AS LoginName,
        SUBSTRING(LogText, CHARINDEX('[CLIENT: ', LogText) + 9, 
                  CHARINDEX(']', LogText) - CHARINDEX('[CLIENT: ', LogText) - 9) AS HostName
    FROM ErrorLogHistory
    WHERE LogText LIKE '%Login succeeded for user%'
),
AggregatedLogs AS (
    SELECT 
        LoginName, 
        HostName, 
        CAST(LastLogin AS DATE) AS AttemptDate,
        COUNT(*) AS SuccessfulLogins,
        MAX(LastLogin) AS LastLogin
    FROM ExtractedLogs
    GROUP BY LoginName, HostName, CAST(LastLogin AS DATE)
)
MERGE INTO LoginAuditSuccessDaily AS Target
USING AggregatedLogs AS Source
ON Target.LoginName = Source.LoginName 
   AND Target.HostName = Source.HostName
   AND Target.AttemptDate = Source.AttemptDate
WHEN MATCHED THEN
    UPDATE SET 
        Target.SuccessfulLogins = Target.SuccessfulLogins + Source.SuccessfulLogins,
        Target.LastLogin = Source.LastLogin
WHEN NOT MATCHED THEN
    INSERT (LoginName, HostName, AttemptDate, SuccessfulLogins, LastLogin)
    VALUES (Source.LoginName, Source.HostName, Source.AttemptDate, Source.SuccessfulLogins, Source.LastLogin);
GO

--failed Logins
WITH ExtractedLogs AS (
    SELECT 
        LogDate AS LastAttempt,
        CASE 
            WHEN CHARINDEX('for user ''', LogText) > 0 THEN 
                SUBSTRING(
                    LogText,
                    CHARINDEX('for user ''', LogText) + LEN('for user '''),
                    CHARINDEX('''', LogText, CHARINDEX('for user ''', LogText) + LEN('for user '''))
                        - (CHARINDEX('for user ''', LogText) + LEN('for user '''))
                )
            ELSE NULL
        END AS LoginName,
        CASE 
            WHEN CHARINDEX('[CLIENT: ', LogText) > 0 THEN 
                SUBSTRING(
                    LogText,
                    CHARINDEX('[CLIENT: ', LogText) + LEN('[CLIENT: '),
                    CHARINDEX(']', LogText, CHARINDEX('[CLIENT: ', LogText)) - (CHARINDEX('[CLIENT: ', LogText) + LEN('[CLIENT: '))
                )
            ELSE NULL
        END AS HostName
    FROM ErrorLogHistory
    WHERE LogText LIKE '%Login failed for user%'
),
AggregatedLogs AS (
    SELECT 
        LoginName, 
        HostName, 
        CAST(LastAttempt AS DATE) AS AttemptDate, 
        COUNT(*) AS FailedLogins,
        MAX(LastAttempt) AS LastAttempt
    FROM ExtractedLogs
    GROUP BY 
        LoginName, 
        HostName, 
        CAST(LastAttempt AS DATE)
)
MERGE INTO LoginAuditFailedDaily AS Target
USING AggregatedLogs AS Source
ON Target.LoginName = Source.LoginName 
   AND Target.HostName = Source.HostName
   AND Target.AttemptDate = Source.AttemptDate
WHEN MATCHED THEN
    UPDATE SET 
        Target.FailedLogins = Target.FailedLogins + Source.FailedLogins,
        Target.LastAttempt = Source.LastAttempt
WHEN NOT MATCHED THEN
    INSERT (LoginName, HostName, AttemptDate, FailedLogins, LastAttempt)
    VALUES (Source.LoginName, Source.HostName, Source.AttemptDate, Source.FailedLogins, Source.LastAttempt);
GO

select * from ErrorLogHistory

