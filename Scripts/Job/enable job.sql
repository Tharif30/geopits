USE msdb;
GO

DECLARE 
    @job_name SYSNAME,
    @job_id UNIQUEIDENTIFIER,
    @schedule_id INT;

DECLARE job_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT job_id, name
FROM msdb.dbo.sysjobs
WHERE name IN
(
 'DBA_Backupdata_collection',
 'DBA_CPU_utilisationdata',
 'DBA_new_loginCreation_alert',
 'DBA_Perfmon_data',
 'DBA_Replica_Disconnected_alert',
 'DBA_SA_password_alert',
 'DBA_TableSize_data',
 'DBA_Waitstat_data'
);

OPEN job_cursor;
FETCH NEXT FROM job_cursor INTO @job_id, @job_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Enabling job: ' + @job_name;

    -- Enable job
    EXEC msdb.dbo.sp_update_job
        @job_id = @job_id,
        @enabled = 1;

    -- Enable all schedules attached to the job
    DECLARE schedule_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.schedule_id
    FROM msdb.dbo.sysjobschedules js
    JOIN msdb.dbo.sysschedules s
        ON js.schedule_id = s.schedule_id
    WHERE js.job_id = @job_id;

    OPEN schedule_cursor;
    FETCH NEXT FROM schedule_cursor INTO @schedule_id;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC msdb.dbo.sp_update_schedule
            @schedule_id = @schedule_id,
            @enabled = 1;

        FETCH NEXT FROM schedule_cursor INTO @schedule_id;
    END

    CLOSE schedule_cursor;
    DEALLOCATE schedule_cursor;

    FETCH NEXT FROM job_cursor INTO @job_id, @job_name;
END

CLOSE job_cursor;
DEALLOCATE job_cursor;
GO
