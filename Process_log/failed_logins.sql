CREATE TABLE LoginAuditFailedDaily (
    LoginName NVARCHAR(255),
    HostName NVARCHAR(255),
    AttemptDate DATE,           -- The day for which the failures are counted
    FailedLogins INT DEFAULT 0, -- Number of failed attempts on that day
    LastAttempt DATETIME        -- The most recent failed attempt on that day
);
GO


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





