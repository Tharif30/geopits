SET ANSI_NULLS, QUOTED_IDENTIFIER ON;
GO

USE Log_info;
GO

WITH EventData AS (
    SELECT 
        CAST(event_data AS XML) AS event_data
    FROM sys.fn_xe_file_target_read_file(N'C:\Users\Public\login_0_133847763861490000.xel', NULL, NULL, NULL)
)
INSERT INTO UserSessionLog (Username, SessionID, EventTime, EventType, Duration)
SELECT
    event_data.value(N'(event/action[@name="username"]/value)[1]', N'NVARCHAR(255)') AS Username,
    event_data.value(N'(event/action[@name="session_id"]/value)[1]', N'INT') AS SessionID,
    event_data.value(N'(event/@timestamp)[1]', N'DATETIME') AS EventTime,
    event_data.value(N'(event/@name)[1]', N'NVARCHAR(100)') AS EventType,
    event_data.value(N'(event/data[@name="duration"]/value)[1]', N'BIGINT') AS Duration
FROM EventData;
GO
