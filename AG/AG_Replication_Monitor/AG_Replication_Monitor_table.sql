use DBADB

CREATE TABLE dbo.AG_Replication_Monitor
(
    ID BIGINT IDENTITY(1,1) PRIMARY KEY,
    CollectionTime          DATETIME        NOT NULL,
    AGName                  SYSNAME         NOT NULL,
    DatabaseName            SYSNAME         NOT NULL,
    LocalReplica            SYSNAME         NOT NULL,
    LocalRole               NVARCHAR(60)    NOT NULL,
    PrimaryReplica          SYSNAME         NULL,

    LogSendQueueKB          BIGINT          NULL,
    LogSendRateKBPerSec     BIGINT          NULL,
    RedoQueueKB             BIGINT          NULL,
    RedoRateKBPerSec        BIGINT          NULL,

    EstimatedLogSendDelaySec DECIMAL(18,2) NULL,
    EstimatedRedoDelaySec    DECIMAL(18,2) NULL,

    SynchronizationState    NVARCHAR(60)    NULL,

    CreatedDate             DATETIME2       NOT NULL
        CONSTRAINT DF_AG_Replication_Monitor_CreatedDate
        DEFAULT (SYSDATETIME())
);

CREATE INDEX IX_AG_Replication_Monitor_Time
ON dbo.AG_Replication_Monitor(CollectionTime);

CREATE INDEX IX_AG_Replication_Monitor_DB
ON dbo.AG_Replication_Monitor(AGName, DatabaseName, CollectionTime);