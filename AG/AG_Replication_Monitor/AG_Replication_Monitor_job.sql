INSERT INTO dbo.AG_Replication_Monitor
(
    CollectionTime,
    AGName,
    DatabaseName,
    LocalReplica,
    LocalRole,
    PrimaryReplica,
    LogSendQueueKB,
    LogSendRateKBPerSec,
    RedoQueueKB,
    RedoRateKBPerSec,
    EstimatedLogSendDelaySec,
    EstimatedRedoDelaySec,
    SynchronizationState
)
SELECT
    GETDATE() AS CollectionTime,
    ag.name AS AGName,
    DB_NAME(drs.database_id) AS DatabaseName,
    ar.replica_server_name AS LocalReplica,
    ars.role_desc AS LocalRole,

    pri.replica_server_name AS PrimaryReplica,

    drs.log_send_queue_size,
    drs.log_send_rate,
    drs.redo_queue_size,
    drs.redo_rate,

    CASE
        WHEN drs.log_send_rate > 0
        THEN CAST(drs.log_send_queue_size * 1.0 / drs.log_send_rate AS DECIMAL(18,2))
    END,

    CASE
        WHEN drs.redo_rate > 0
        THEN CAST(drs.redo_queue_size * 1.0 / drs.redo_rate AS DECIMAL(18,2))
    END,

    drs.synchronization_state_desc
FROM sys.dm_hadr_database_replica_states drs
JOIN sys.availability_replicas ar
    ON drs.replica_id = ar.replica_id
JOIN sys.dm_hadr_availability_replica_states ars
    ON drs.replica_id = ars.replica_id
JOIN sys.availability_groups ag
    ON ag.group_id = ar.group_id
LEFT JOIN sys.availability_replicas pri
    ON pri.group_id = ar.group_id
LEFT JOIN sys.dm_hadr_availability_replica_states priState
    ON pri.replica_id = priState.replica_id
WHERE priState.role_desc = 'PRIMARY';