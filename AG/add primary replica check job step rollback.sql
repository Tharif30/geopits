USE msdb;
GO

DECLARE 
    @job_id UNIQUEIDENTIFIER,
    @job_name SYSNAME,
    @step_id INT;

DECLARE job_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT j.job_id, j.name
FROM msdb.dbo.sysjobs j
WHERE j.name IN
(
 'DBA_Backupdata_collection',
 'DBA_BlockingQuery_alert',
 'DBA_CPU_utilisationdata',
 'DBA_Database_size report',
 'DBA_Disk_Space_Alert',
 'DBA_diskSpace_alert',
 'DBA_Highconnection_alert',
 'DBA_HighCPU_alert',
 'DBA_Index_dataCollect',
 'DBA_IndexFragmentation_report',
 'DBA_Long_running_alert',
 'DBA_Longrunning_closed_alert',
 'DBA_Low_PLE_alert',
 'DBA_new_loginCreation_alert',
 'DBA_Perfmon_data',
 'DBA_Replica_Disconnected_alert',
 'DBA_SA_password_alert',
 'DBA_sqlhealthcheck_report',
 'DBA_TableSize_data',
 'DBA_Tablesize_report',
 'DBA_unuseIndex',
 'DBA_Waitstat_data'
);

OPEN job_cursor;
FETCH NEXT FROM job_cursor INTO @job_id, @job_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Get step id for Primary Replica check
    SELECT @step_id = step_id
    FROM msdb.dbo.sysjobsteps
    WHERE job_id = @job_id
      AND step_name = N'Check Primary Replica';

    IF @step_id IS NOT NULL
    BEGIN
        PRINT 'Removing step from job: ' + @job_name;

        EXEC msdb.dbo.sp_delete_jobstep
            @job_id = @job_id,
            @step_id = @step_id;
    END
    ELSE
    BEGIN
        PRINT 'Step not found for job: ' + @job_name;
    END

    FETCH NEXT FROM job_cursor INTO @job_id, @job_name;
END

CLOSE job_cursor;
DEALLOCATE job_cursor;
GO
