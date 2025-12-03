
CREATE TABLE ErrorLogHistory (
    LogDate DATETIME,
    ProcessInfo NVARCHAR(50),
    LogText NVARCHAR(MAX),
    LogFile NVARCHAR(50)  
);


select top 5 * from ErrorLogHistory where ProcessInfo='Logon' AND LogText like 'Login failed for user%' ;

SELECT * 
FROM ErrorLogHistory 
WHERE ProcessInfo = 'Logon'
  AND CAST(LogDate AS DATE) = '2025-02-25';


truncate table ErrorLogHistory


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


SELECT * 
FROM ErrorLogHistory 
WHERE ProcessInfo = 'Logon'
  AND CAST(LogDate AS DATE) = '2025-02-25'
  order by Logdate desc;