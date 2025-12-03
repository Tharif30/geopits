USE [DBADB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[PerfMonData](
	[Counter] [nvarchar](770) NULL,
	[Value] [decimal](38, 2) NULL,
	[CaptureDate] [datetime] NULL
) ON [PRIMARY]
GO


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
