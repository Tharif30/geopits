--Query Showing Job Name, Run Date/Time, Status, and Runtime

SELECT TOP (100)
    j.name AS JobName,
    
    -- Convert run_date + run_time to a real datetime
    msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunDateTime,

    -- runtime (duration) converted to HH:MM:SS
    RIGHT('0' + CAST(h.run_duration / 10000 AS VARCHAR(2)), 2) + ':' +
    RIGHT('0' + CAST((h.run_duration % 10000) / 100 AS VARCHAR(2)), 2) + ':' +
    RIGHT('0' + CAST(h.run_duration % 100 AS VARCHAR(2)), 2) AS RunDuration,
    
    CASE 
        WHEN h.run_status = 0 THEN 'Failed'
        WHEN h.run_status = 1 THEN 'Succeeded'
        WHEN h.run_status = 2 THEN 'Retry'
        WHEN h.run_status = 3 THEN 'Canceled'
        WHEN h.run_status = 4 THEN 'In Progress'
        ELSE 'Unknown'
    END AS JobStatus,
    
    h.message
FROM msdb.dbo.sysjobhistory h
INNER JOIN msdb.dbo.sysjobs j 
    ON j.job_id = h.job_id
WHERE h.job_id = 'FD37EF32-01B4-48A6-B75B-B6500B416820'
  AND h.step_id = 0   -- overall job result
ORDER BY h.run_date DESC, h.run_time DESC;
