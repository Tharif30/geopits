SELECT 
    j.name AS JobName,
    ja.start_execution_date AS StartTime,
    DATEDIFF(MINUTE, ja.start_execution_date, GETDATE()) AS MinutesRunning,
    s.step_name AS CurrentStep,
    ja.job_id
FROM msdb.dbo.sysjobactivity ja
JOIN msdb.dbo.sysjobs j 
    ON j.job_id = ja.job_id
LEFT JOIN msdb.dbo.sysjobsteps s
    ON s.job_id = ja.job_id 
    AND s.step_id = ja.last_executed_step_id + 1
WHERE ja.stop_execution_date IS NULL    -- still running
  AND ja.start_execution_date IS NOT NULL;
