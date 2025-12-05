USE msdb;
GO

SELECT 
    secondary_server,
    secondary_database,
    last_restored_file,
    last_restored_date,
    last_restored_file_size,
    last_restored_duration,
    last_restored_status
FROM dbo.log_shipping_secondary_databases
ORDER BY last_restored_date DESC;


USE msdb;
GO

SELECT 
    j.name AS JobName,
    h.run_date,
    h.run_time,
    h.step_id,
    h.step_name,
    h.sql_message_id,
    h.sql_severity,
    h.message
FROM dbo.sysjobhistory h
INNER JOIN dbo.sysjobs j
    ON j.job_id = h.job_id
WHERE j.name LIKE 'LSRestore_%'  -- restore job naming convention
ORDER BY h.run_date DESC, h.run_time DESC;
