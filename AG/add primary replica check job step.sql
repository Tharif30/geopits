USE msdb;
GO

DECLARE 
    @job_id UNIQUEIDENTIFIER,
    @job_name SYSNAME;

DECLARE job_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT job_id, name
FROM msdb.dbo.sysjobs
WHERE name IN
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
    PRINT 'Adding Primary check step to job: ' + @job_name;

    -- Add Step 1
    EXEC msdb.dbo.sp_add_jobstep
        @job_id = @job_id,
        @step_id = 1,
        @step_name = N'Check Primary Replica',
        @subsystem = N'TSQL',
        @database_name = N'master',
        @command = N'
IF NOT EXISTS
(
    SELECT 1
    FROM sys.dm_hadr_availability_replica_states ars
    JOIN sys.availability_replicas ar
        ON ars.replica_id = ar.replica_id
    WHERE ars.is_local = 1
      AND ars.role_desc = ''PRIMARY''
)
BEGIN
    PRINT ''Job running on Secondary replica. Stopping execution.'';
    RAISERROR (''This job must run on PRIMARY replica only.'', 16, 1);
END
ELSE
BEGIN
    PRINT ''Job running on PRIMARY replica. Proceeding...'';
END
',
        @on_success_action = 3,  -- Go to next step
        @on_fail_action = 2;     -- Quit job reporting failure

    FETCH NEXT FROM job_cursor INTO @job_id, @job_name;
END

CLOSE job_cursor;
DEALLOCATE job_cursor;
GO
