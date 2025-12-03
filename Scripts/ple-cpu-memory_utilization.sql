--======================
--step 1
USE DBADB
go
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
insert into DBADB.dbo.CPUUtilisationdata
SELECT
getdate(),
         cpu_idle = record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int'),
         cpu_sql = record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int'),
Other_process = 100 - record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') - record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int')
FROM (
         SELECT TOP 1 CONVERT(XML, record) AS record
         FROM sys.dm_os_ring_buffers
         WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
         AND record LIKE '% %'
ORDER BY TIMESTAMP DESC
)
as cpu_usage

--====================
--step2
USE master;
GO

INSERT INTO [DBADB].[dbo].[MemoryUtilisationdata]
SELECT 
    GETDATE(),
    SQL_current_Memory_usage_mb/1024.0 AS [SQL_current_Memory_usage_Gb],
    SQL_Max_Memory_target_mb/1024.0 AS [SQL_Max_Memory_target_Gb], 
    OS_Total_Memory_mb/1024.0 AS [OS_Total_Memory_Gb],
    OS_Available_Memory_mb/1024.0 AS [OS_Available_Memory_Gb] 
FROM fn_checkSQLMemory();
GO

--==================================
--step3
USE DBADB

GO

SET NOCOUNT ON;

DECLARE @PerfCounters TABLE

    (

      [Counter] NVARCHAR(770) ,

      [CounterType] INT ,

      [FirstValue] DECIMAL(38, 2) ,

      [FirstDateTime] DATETIME ,

      [SecondValue] DECIMAL(38, 2) ,

      [SecondDateTime] DATETIME ,

      [ValueDiff] AS ( [SecondValue] - [FirstValue] ) ,

      [TimeDiff] AS ( DATEDIFF(SS, FirstDateTime, SecondDateTime) ) ,

      [CounterValue] DECIMAL(38, 2)

    );

INSERT  INTO @PerfCounters

        ( [Counter] ,

          [CounterType] ,

          [FirstValue] ,

          [FirstDateTime]

        )

        SELECT  RTRIM([object_name]) + N':' + RTRIM([counter_name]) + N':'

                + RTRIM([instance_name]) ,

                [cntr_type] ,

                [cntr_value] ,

                GETDATE()

        FROM    sys.dm_os_performance_counters

        WHERE   [counter_name] IN ( N'Page life expectancy',

                                    N'Lazy writes/sec', N'Page reads/sec',

                                    N'Page writes/sec', N'Free Pages',

                                    N'Free list stalls/sec',

                                    N'User Connections',

                                    N'Lock Waits/sec',

                                    N'Number of Deadlocks/sec',

                                    N'Transactions/sec',

                                    N'Forwarded Records/sec',

                                    N'Index Searches/sec',

                                    N'Full Scans/sec',

                                    N'Batch Requests/sec',

                                    N'SQL Compilations/sec',

                                    N'SQL Re-Compilations/sec',

                                    N'Total Server Memory (KB)',

                                    N'Target Server Memory (KB)',

                                    N'Latch Waits/sec' )

        ORDER BY [object_name] + N':' + [counter_name] + N':'

                + [instance_name];

WAITFOR DELAY '00:00:10';

UPDATE  @PerfCounters

SET     [SecondValue] = [cntr_value] ,

        [SecondDateTime] = GETDATE()

FROM    sys.dm_os_performance_counters

WHERE   [Counter] = RTRIM([object_name]) + N':' + RTRIM([counter_name])

                                                                  + N':'

        + RTRIM([instance_name])

        AND [counter_name] IN ( N'Page life expectancy', 

                                N'Lazy writes/sec',

                                N'Page reads/sec', N'Page writes/sec',

                                N'Free Pages', N'Free list stalls/sec',

                                N'User Connections', N'Lock Waits/sec',

                                N'Number of Deadlocks/sec',

                                N'Transactions/sec',

                                N'Forwarded Records/sec',

                                N'Index Searches/sec', N'Full Scans/sec',

                                N'Batch Requests/sec',

                                N'SQL Compilations/sec',

                                N'SQL Re-Compilations/sec',

                                N'Total Server Memory (KB)',

                                N'Target Server Memory (KB)',

                                N'Latch Waits/sec' );

UPDATE  @PerfCounters

SET     [CounterValue] = [ValueDiff] / [TimeDiff]

WHERE   [CounterType] = 272696576;

UPDATE  @PerfCounters

SET     [CounterValue] = [SecondValue]

WHERE   [CounterType] <> 272696576;

INSERT  INTO [dbo].[PerfMonData]

        ( [Counter] ,

          [Value] ,

          [CaptureDate]

        )

        SELECT  [Counter] ,

                [CounterValue] ,

                [SecondDateTime]

        FROM    @PerfCounters;
--==============================================
