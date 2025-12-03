WITH JobHistory AS (
    SELECT
        job_id,
        run_date,
        run_time,
        run_duration,
        run_status,
        ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY run_date DESC, run_time DESC) AS rn
    FROM msdb.dbo.sysjobhistory --it holds the data  about the jobs
    WHERE step_id = 0  -- Only include job outcome (not individual steps)
)
SELECT
    j.name AS JobName,
    msdb.dbo.agent_datetime(h.run_date, h.run_time) AS LastRunDateTime, --agent_datetime combines the data and time
    -- Duration formatted as HH:MM:SS
    RIGHT('00' + CAST(h.run_duration / 10000 AS VARCHAR), 2) + ':' +
    RIGHT('00' + CAST((h.run_duration % 10000) / 100 AS VARCHAR), 2) + ':' +
    RIGHT('00' + CAST(h.run_duration % 100 AS VARCHAR), 2) AS RunDuration,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Cancelled'
        WHEN 4 THEN 'In Progress'
        ELSE 'Unknown'
    END AS RunStatus
FROM msdb.dbo.sysjobs j --holds job_name,date_created,date_modified
LEFT JOIN JobHistory h ON j.job_id = h.job_id AND h.rn = 1
ORDER BY LastRunDateTime DESC;

--Holds run date,run time,job outcome,job id
select * FROM msdb.dbo.sysjobhistory;

select * FROM msdb.dbo.sysjobs