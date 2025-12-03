
use Log_info;


CREATE TABLE LoginAuditSuccessDaily (
    LoginName NVARCHAR(255),
    HostName NVARCHAR(255),
    AttemptDate DATE,              -- The date (day) of the login attempts
    SuccessfulLogins INT DEFAULT 0, -- Count of successful login attempts on that day
    LastLogin DATETIME             -- The time of the last successful login on that day
);
GO


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


