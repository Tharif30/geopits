USE [DBADB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

 
/**************************/  
/***** SQL SERVER HEALTH CHECK REPORT - HTML ********/
/**************************/  
-- Tested: SQL Server 2008 R2, 2012, 2014, 2016, 2017, 2019 and 2022  
-- Report Type: HTML Report Delivers to Mail Box  
-- Parameters: DBMail Profile Name *, Email ID *, Server Name (Optional);   
-- Reports: SQL Server Instance Details  
--   Last 4 days Critical Errors from ErrorLog  
--   Instance Last Recycle Information  
--   Tempdb File Usage  
--             Free Disk Space Report
--   CPU Usage  
--   Memory Usage  
--   Performance Counters Data  
--   Missing Backup Report  
--   Connection Information  
--   Log Space Usage Report  
--   Job Status Report  
--   Blocking Report  
--   Long running Transactions
--   Failed Jobs in Last 24Hrs
/**************************/  
/**************************/  
CREATE    PROCEDURE [dbo].[SQLhealthcheck_report] (  
  @MailProfile NVARCHAR(200),   
  @MailID NVARCHAR(2000),  
  @Server VARCHAR(100) = NULL)  
AS  
BEGIN  
SET NOCOUNT ON;  
SET ARITHABORT ON;  
  
DECLARE @ServerName VARCHAR(100);  
SET @ServerName = ISNULL(@Server,@@SERVERNAME);  
  
/*********************/  
/****** Server Reboot Details ********/  
/*********************/  
  
CREATE TABLE #RebootDetails                                
(                                
 LastRecycle datetime,                                
 CurrentDate datetime,                                
 UpTimeInDays varchar(100)                          
)                        
Insert into #RebootDetails          
SELECT sqlserver_start_time 'Last Recycle',GetDate() 'Current Date', DATEDIFF(DD, sqlserver_start_time,GETDATE())'Up Time in Days'  
FROM sys.dm_os_sys_info;  
  
/*********************/  
/****** Errors audit for last 4 Days *****/  
/*********************/  
  
--CREATE TABLE #ErrorLogInfo                                
--(                                
-- LogDate  datetime,  
-- processinfo varchar(500),                                
-- LogInfo  varchar(1000)                                 
--)      
  
--DECLARE @A VARCHAR(10), @B VARCHAR(10);  
--SELECT @A = CONVERT(VARCHAR(20),GETDATE()-1,112);  
--SELECT @B = CONVERT(VARCHAR(20),GETDATE()+1,112);  
--Insert into #ErrorLogInfo  
--EXEC xp_ReadErrorLog 0, 1,N'Login', N'Failed', @A,@B,'DESC';  
 
 
  
/*********************/  
/***** Windows Disk Space Details ******/  
/*********************/  
 
DECLARE @Result INT
                , @objFSO INT
                , @Drv INT
                , @cDrive VARCHAR(13)
                , @Size VARCHAR(50)
                , @Free VARCHAR(50)
                , @Label varchar(10);
 
CREATE TABLE ##_DriveSpace
                (
                DriveLetter CHAR(1) not null
                , FreeSpace VARCHAR(10) not null
 
                )
 
CREATE TABLE ##_DriveInfo
                (
                DriveLetter CHAR(1)
                , TotalSpace bigint
                , FreeSpace bigint
                , Label varchar(10)
                )
 
INSERT INTO ##_DriveSpace
                EXEC master.dbo.xp_fixeddrives;
 
 
-- Iterate through drive letters.
DECLARE curDriveLetters CURSOR
                FOR SELECT driveletter FROM ##_DriveSpace
 
DECLARE @DriveLetter char(1)
                OPEN curDriveLetters
 
FETCH NEXT FROM curDriveLetters INTO @DriveLetter
WHILE (@@fetch_status <> -1)
BEGIN
                IF (@@fetch_status <> -2)
                BEGIN
 
                                SET @cDrive = 'GetDrive("' + @DriveLetter + '")'
 
                                                EXEC @Result = sp_OACreate 'Scripting.FileSystemObject', @objFSO OUTPUT
 
                                                                IF @Result = 0
 
                                                                                EXEC @Result = sp_OAMethod @objFSO, @cDrive, @Drv OUTPUT
 
                                                                IF @Result = 0
 
                                                                                EXEC @Result = sp_OAGetProperty @Drv,'TotalSize', @Size OUTPUT
 
                                                                IF @Result = 0
 
                                                                                EXEC @Result = sp_OAGetProperty @Drv,'FreeSpace', @Free OUTPUT
 
                                                                IF @Result = 0
 
                                                                                EXEC @Result = sp_OAGetProperty @Drv,'VolumeName', @Label OUTPUT
 
                                                                IF @Result <> 0
 
                                                                                EXEC sp_OADestroy @Drv
                                                                                EXEC sp_OADestroy @objFSO
 
                                                SET @Size = (CONVERT(BIGINT,@Size) / 1048576 )
 
                                                SET @Free = (CONVERT(BIGINT,@Free) / 1048576 )
 
                                                INSERT INTO ##_DriveInfo
                                                                VALUES (@DriveLetter, @Size, @Free, @Label)
 
                END
                FETCH NEXT FROM curDriveLetters INTO @DriveLetter
END
 
CLOSE curDriveLetters
DEALLOCATE curDriveLetters
 
PRINT 'Drive information for server ' + @@SERVERNAME + '.'
PRINT ''
 
-- Produce report.
create table ##temp( DriveLetter VARCHAR(10),FreeSpace_GB VARCHAR(100),UsedSpace_GB varchar(100), TotalSpace_GB VARCHAR(100), Percentage_Free varchar(100))
 
INSERT INTO ##temp
SELECT DriveLetter
                , FreeSpace/1024 AS [FreeSpace_GB]
                , (TotalSpace - FreeSpace)/1024 AS [UsedSpace_GB]
                , TotalSpace/1024 AS [TotalSpace_GB]
                , (convert(INT, (CONVERT(NUMERIC(9,2),FreeSpace) / CONVERT(NUMERIC(9,2),TotalSpace)) * 100)) AS [Percentage_Free]
FROM ##_DriveInfo
ORDER BY [DriveLetter] ASC
  
/*********************/  
/***** SQL Server CPU Usage Details ******/  
/*********************/  
Create table #CPU(               
servername varchar(100),                           
EventTime2 datetime,                            
SQLProcessUtilization varchar(50),                           
SystemIdle varchar(50),  
OtherProcessUtilization varchar(50),  
load_date datetime                            
)      
DECLARE @ts BIGINT;  DECLARE @lastNmin TINYINT;  
SET @lastNmin = 240;  
SELECT @ts =(SELECT cpu_ticks/(cpu_ticks/ms_ticks) FROM sys.dm_os_sys_info);   
insert into #CPU  
SELECT TOP 10 * FROM (  
SELECT TOP(@lastNmin)  
  @ServerName AS 'ServerName',  
  DATEADD(ms,-1 *(@ts - [timestamp]),GETDATE())AS [Event_Time],   
  SQLProcessUtilization AS [SQLServer_CPU_Utilization],   
  SystemIdle AS [System_Idle_Process],   
  100 - SystemIdle - SQLProcessUtilization AS [Other_Process_CPU_Utilization],  
  GETDATE() AS 'LoadDate'  
FROM (SELECT record.value('(./Record/@id)[1]','int')AS record_id,   
record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]','int')AS [SystemIdle],   
record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]','int')AS [SQLProcessUtilization],   
[timestamp]        
FROM (SELECT[timestamp], convert(xml, record) AS [record]               
FROM sys.dm_os_ring_buffers               
WHERE ring_buffer_type =N'RING_BUFFER_SCHEDULER_MONITOR'AND record LIKE'%%')AS x )AS y   
ORDER BY SystemIdle ASC) d  
  
/*********************/  
/***** SQL Server Memory Usage Details *****/  
/*********************/  
  
CREATE TABLE #Memory_BPool (  
BPool_Committed_MB VARCHAR(50),  
BPool_Commit_Tgt_MB VARCHAR(50),  
BPool_Visible_MB VARCHAR(50));  
  
-- SQL server 2008 / 2008 R2  
/**  
-- SQL server 2012 / 2014 / 2016  
INSERT INTO #Memory_BPool   
SELECT  
      (committed_kb)/1024.0 as BPool_Committed_MB,  
      (committed_target_kb)/1024.0 as BPool_Commit_Tgt_MB,  
      (visible_target_kb)/1024.0 as BPool_Visible_MB  
FROM  sys.dm_os_sys_info;  
**/  
CREATE TABLE #Memory_sys (  
total_physical_memory_mb VARCHAR(50),  
available_physical_memory_mb VARCHAR(50),  
total_page_file_mb VARCHAR(50),  
available_page_file_mb VARCHAR(50),  
Percentage_Used VARCHAR(50),  
system_memory_state_desc VARCHAR(50));  
  
INSERT INTO #Memory_sys  
select  
      total_physical_memory_kb/1024 AS total_physical_memory_mb,  
      available_physical_memory_kb/1024 AS available_physical_memory_mb,  
      total_page_file_kb/1024 AS total_page_file_mb,  
      available_page_file_kb/1024 AS available_page_file_mb,  
      100 - (100 * CAST(available_physical_memory_kb AS DECIMAL(18,3))/CAST(total_physical_memory_kb AS DECIMAL(18,3)))   
      AS 'Percentage_Used',  
      system_memory_state_desc  
from  sys.dm_os_sys_memory;  
  
  
CREATE TABLE #Memory_process(  
physical_memory_in_use_GB VARCHAR(50),  
locked_page_allocations_GB VARCHAR(50),  
virtual_address_space_committed_GB VARCHAR(50),  
available_commit_limit_GB VARCHAR(50),  
page_fault_count VARCHAR(50))  
  
INSERT INTO #Memory_process  
select  
      physical_memory_in_use_kb/1048576.0 AS 'physical_memory_in_use(GB)',  
      locked_page_allocations_kb/1048576.0 AS 'locked_page_allocations(GB)',  
      virtual_address_space_committed_kb/1048576.0 AS 'virtual_address_space_committed(GB)',  
      available_commit_limit_kb/1048576.0 AS 'available_commit_limit(GB)',  
      page_fault_count as 'page_fault_count'  
from  sys.dm_os_process_memory;  
  
  
CREATE TABLE #Memory(  
Parameter VARCHAR(200),  
Value VARCHAR(100));  
  
INSERT INTO #Memory   
SELECT 'BPool_Committed_MB',BPool_Committed_MB FROM #Memory_BPool  
UNION  
SELECT 'BPool_Commit_Tgt_MB', BPool_Commit_Tgt_MB FROM #Memory_BPool  
UNION   
SELECT 'BPool_Visible_MB', BPool_Visible_MB FROM #Memory_BPool  
UNION  
SELECT 'total_physical_memory_mb',total_physical_memory_mb FROM #Memory_sys  
UNION  
SELECT 'available_physical_memory_mb',available_physical_memory_mb FROM #Memory_sys  
UNION  
SELECT 'total_page_file_mb',total_page_file_mb FROM #Memory_sys  
UNION  
SELECT 'available_page_file_mb',available_page_file_mb FROM #Memory_sys  
UNION  
SELECT 'Percentage_Used',Percentage_Used FROM #Memory_sys  
UNION  
SELECT 'system_memory_state_desc',system_memory_state_desc FROM #Memory_sys  
UNION  
SELECT 'physical_memory_in_use_GB',physical_memory_in_use_GB FROM #Memory_process  
UNION  
SELECT 'locked_page_allocations_GB',locked_page_allocations_GB FROM #Memory_process  
UNION  
SELECT 'virtual_address_space_committed_GB',virtual_address_space_committed_GB FROM #Memory_process  
UNION  
SELECT 'available_commit_limit_GB',available_commit_limit_GB FROM #Memory_process  
UNION  
SELECT 'page_fault_count',page_fault_count FROM #Memory_process;  
  
  
/**********************/  
/***** Performance Counter Details ********/  
/**********************/  
  
CREATE TABLE #PerfCntr_Data(  
Parameter VARCHAR(300),  
Value VARCHAR(100));  
  
-- Get size of SQL Server Page in bytes  
DECLARE @pg_size INT, @Instancename varchar(50)  
SELECT @pg_size = low from master..spt_values where number = 1 and type = 'E'  
  
-- Extract perfmon counters to a temporary table  
IF OBJECT_ID('tempdb..#perfmon_counters') is not null DROP TABLE #perfmon_counters  
SELECT * INTO #perfmon_counters FROM sys.dm_os_performance_counters;  
  
-- Get SQL Server instance name as it require for capturing Buffer Cache hit Ratio  
SELECT  @Instancename = LEFT([object_name], (CHARINDEX(':',[object_name])))   
FROM    #perfmon_counters   
WHERE   counter_name = 'Buffer cache hit ratio';  
  
INSERT INTO #PerfCntr_Data  
SELECT CONVERT(VARCHAR(300),Cntr) AS Parameter, CONVERT(VARCHAR(100),Value) AS Value  
FROM  
(  
SELECT  'Total Server Memory (GB)' as Cntr,  
        (cntr_value/1048576.0) AS Value   
FROM    #perfmon_counters   
WHERE   counter_name = 'Total Server Memory (KB)'  
UNION ALL  
SELECT  'Target Server Memory (GB)',   
        (cntr_value/1048576.0)   
FROM    #perfmon_counters   
WHERE   counter_name = 'Target Server Memory (KB)'  
UNION ALL  
SELECT  'Connection Memory (MB)',   
        (cntr_value/1024.0)   
FROM    #perfmon_counters   
WHERE   counter_name = 'Connection Memory (KB)'  
UNION ALL  
SELECT  'Lock Memory (MB)',   
        (cntr_value/1024.0)   
FROM    #perfmon_counters   
WHERE   counter_name = 'Lock Memory (KB)'  
UNION ALL  
SELECT  'SQL Cache Memory (MB)',   
        (cntr_value/1024.0)   
FROM    #perfmon_counters   
WHERE   counter_name = 'SQL Cache Memory (KB)'  
UNION ALL  
SELECT  'Optimizer Memory (MB)',   
        (cntr_value/1024.0)   
FROM    #perfmon_counters   
WHERE   counter_name = 'Optimizer Memory (KB) '  
UNION ALL  
SELECT  'Granted Workspace Memory (MB)',   
        (cntr_value/1024.0)   
FROM    #perfmon_counters   
WHERE   counter_name = 'Granted Workspace Memory (KB) '  
UNION ALL  
SELECT  'Cursor memory usage (MB)',   
        (cntr_value/1024.0)   
FROM    #perfmon_counters   
WHERE   counter_name = 'Cursor memory usage' and instance_name = '_Total'  
UNION ALL  
SELECT  'Total pages Size (MB)',   
        (cntr_value*@pg_size)/1048576.0   
FROM    #perfmon_counters   
WHERE   object_name= @Instancename+'Buffer Manager'   
        and counter_name = 'Total pages'  
UNION ALL  
SELECT  'Database pages (MB)',   
        (cntr_value*@pg_size)/1048576.0   
FROM    #perfmon_counters   
WHERE   object_name = @Instancename+'Buffer Manager' and counter_name = 'Database pages'  
UNION ALL  
SELECT  'Free pages (MB)',   
        (cntr_value*@pg_size)/1048576.0   
FROM    #perfmon_counters   
WHERE   object_name = @Instancename+'Buffer Manager'   
        and counter_name = 'Free pages'  
UNION ALL  
SELECT  'Reserved pages (MB)',   
        (cntr_value*@pg_size)/1048576.0   
FROM    #perfmon_counters   
WHERE   object_name=@Instancename+'Buffer Manager'   
        and counter_name = 'Reserved pages'  
UNION ALL  
SELECT  'Stolen pages (MB)',   
        (cntr_value*@pg_size)/1048576.0   
FROM    #perfmon_counters   
WHERE   object_name=@Instancename+'Buffer Manager'   
        and counter_name = 'Stolen pages'  
UNION ALL  
SELECT  'Cache Pages (MB)',   
        (cntr_value*@pg_size)/1048576.0   
FROM    #perfmon_counters   
WHERE   object_name=@Instancename+'Plan Cache'   
        and counter_name = 'Cache Pages' and instance_name = '_Total'  
UNION ALL  
SELECT  'Page Life Expectency in seconds',  
        cntr_value   
FROM    #perfmon_counters   
WHERE   object_name=@Instancename+'Buffer Manager'   
        and counter_name = 'Page life expectancy'  
UNION ALL  
SELECT  'Free list stalls/sec',  
        cntr_value   
FROM    #perfmon_counters   
WHERE   object_name=@Instancename+'Buffer Manager'   
        and counter_name = 'Free list stalls/sec'  
UNION ALL  
SELECT  'Checkpoint pages/sec',  
        cntr_value   
FROM    #perfmon_counters   
WHERE   object_name=@Instancename+'Buffer Manager'   
        and counter_name = 'Checkpoint pages/sec'  
UNION ALL  
SELECT  'Lazy writes/sec',  
        cntr_value   
FROM    #perfmon_counters   
WHERE   object_name=@Instancename+'Buffer Manager'   
        and counter_name = 'Lazy writes/sec'  
UNION ALL  
SELECT  'Memory Grants Pending',  
        cntr_value   
FROM    #perfmon_counters   
WHERE   object_name=@Instancename+'Memory Manager'   
        and counter_name = 'Memory Grants Pending'  
UNION ALL  
SELECT  'Memory Grants Outstanding',  
        cntr_value   
FROM    #perfmon_counters   
WHERE   object_name=@Instancename+'Memory Manager'   
        and counter_name = 'Memory Grants Outstanding'  
UNION ALL  
SELECT  'process_physical_memory_low',  
        process_physical_memory_low   
FROM    sys.dm_os_process_memory WITH (NOLOCK)  
UNION ALL  
SELECT  'process_virtual_memory_low',  
        process_virtual_memory_low   
FROM    sys.dm_os_process_memory WITH (NOLOCK)  
UNION ALL  
SELECT  'Max_Server_Memory (MB)' ,  
        [value_in_use]   
FROM    sys.configurations   
WHERE   [name] = 'max server memory (MB)'  
UNION ALL  
SELECT  'Min_Server_Memory (MB)' ,  
        [value_in_use]   
FROM    sys.configurations   
WHERE   [name] = 'min server memory (MB)'  
UNION ALL  
SELECT  'BufferCacheHitRatio',  
        (a.cntr_value * 1.0 / b.cntr_value) * 100.0   
FROM    sys.dm_os_performance_counters a  
        JOIN (SELECT cntr_value,OBJECT_NAME FROM sys.dm_os_performance_counters  
              WHERE counter_name = 'Buffer cache hit ratio base' AND   
                    OBJECT_NAME = @Instancename+'Buffer Manager') b ON   
                    a.OBJECT_NAME = b.OBJECT_NAME WHERE a.counter_name = 'Buffer cache hit ratio'   
                    AND a.OBJECT_NAME = @Instancename+'Buffer Manager') AS P;  
  
  
  
/**********************/  
/***** Database Backup Report *********/  
/**********************/  
  
CREATE TABLE #Backup_Report(  
Database_Name VARCHAR(300),  
Last_Backup_Date VARCHAR(50));  
  
INSERT INTO #Backup_Report  
--Databases with data backup over 48 hours old   
SELECT Database_Name, last_db_backup_date AS Last_Backup_Date FROM (  
SELECT CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server,   
  msdb.dbo.backupset.database_name,   
  MAX(msdb.dbo.backupset.backup_finish_date) AS last_db_backup_date,   
  DATEDIFF(hh, MAX(msdb.dbo.backupset.backup_finish_date), GETDATE()) AS [Backup Age (Hours)]   
FROM msdb.dbo.backupset   
WHERE   msdb.dbo.backupset.type = 'D'    
GROUP BY msdb.dbo.backupset.database_name   
HAVING (MAX(msdb.dbo.backupset.backup_finish_date) < DATEADD(DD, -7, GETDATE()))    
UNION    
--Databases without any backup history   
SELECT CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server,    
  sd.NAME AS database_name,    
  NULL AS [Last Data Backup Date],    
  9999 AS [Backup Age (Hours)]    
FROM master.dbo.sysdatabases sd   
  LEFT JOIN msdb.dbo.backupset bs  
  ON sd.name  = bs.database_name   
WHERE bs.database_name IS NULL AND sd.name <> 'tempdb' ) AS B   
ORDER BY Database_Name;   
  
/*********************/  
/****** Failed Jobs in Last 24Hrs ********/  
/*********************/
 
create table #Failed_jobs(date_time varchar(100),
job_name varchar(200),
job_step varchar(10),
error_message varchar(max))
 
insert into #Failed_jobs
SELECT MSDB.dbo.agent_datetime(jh.run_date,jh.run_time) as date_time
,j.name as job_name,js.step_id as job_step,jh.message as error_message
FROM msdb.dbo.sysjobs AS j
INNER JOIN msdb.dbo.sysjobsteps AS js ON js.job_id = j.job_id
INNER JOIN msdb.dbo.sysjobhistory AS jh ON jh.job_id = j.job_id AND jh.step_id = js.step_id
WHERE jh.run_status = 0 AND MSDB.dbo.agent_datetime(jh.run_date,jh.run_time) >= GETDATE()-1 and j.[name] <> 'geomon_test'
ORDER BY MSDB.dbo.agent_datetime(jh.run_date,jh.run_time) DESC
  
/*********************/  
/***** Currently Running Jobs Info *******/  
/*********************/  
Create table #JobInfo(               
spid varchar(10),                           
lastwaittype varchar(100),                           
dbname varchar(100),                           
login_time varchar(100),                           
status varchar(100),                           
opentran varchar(100),                           
hostname varchar(100),                          
JobName varchar(100),                          
command nvarchar(2000),  
domain varchar(100),   
loginname varchar(100)     
)   
insert into #JobInfo  
SELECT  distinct p.spid,p.lastwaittype,DB_NAME(p.dbid),p.login_time,p.status,p.open_tran,p.hostname,J.name,  
p.cmd,p.nt_domain,p.loginame  
FROM master..sysprocesses p  
INNER JOIN msdb..sysjobs j ON   
substring(left(j.job_id,8),7,2) + substring(left(j.job_id,8),5,2) + substring(left(j.job_id,8),3,2) + substring(left(j.job_id,8),1,2) = substring(p.program_name, 32, 8)   
Inner join msdb..sysjobactivity sj on j.job_id=sj.job_id  
WHERE program_name like'SQLAgent - TSQL JobStep (Job %' and sj.stop_execution_date is null  
  
/*********************/  
/****** Tempdb File Info *********/  
/*********************/  
-- tempdb file usage  
Create table #tempdbfileusage(               
servername varchar(100),                           
databasename varchar(100),                           
filename varchar(100),                           
physicalName varchar(100),                           
filesizeMB varchar(100),                           
availableSpaceMB varchar(100),                           
percentfull varchar(100)   
)   
  
DECLARE @TEMPDBSQL NVARCHAR(4000);  
SET @TEMPDBSQL = ' USE Tempdb;  
SELECT  CONVERT(VARCHAR(100), @@SERVERNAME) AS [server_name]  
                ,db.name AS [database_name]  
                ,mf.[name] AS [file_logical_name]  
                ,mf.[filename] AS[file_physical_name]  
                ,convert(FLOAT, mf.[size]/128) AS [file_size_mb]               
                ,convert(FLOAT, (mf.[size]/128 - (CAST(FILEPROPERTY(mf.[name], ''SpaceUsed'') AS int)/128))) as [available_space_mb]  
                ,convert(DECIMAL(38,2), (CAST(FILEPROPERTY(mf.[name], ''SpaceUsed'') AS int)/128.0)/(mf.[size]/128.0))*100 as [percent_full]      
FROM   tempdb.dbo.sysfiles mf  
JOIN      master..sysdatabases db  
ON         db.dbid = db_id()';  
--PRINT @TEMPDBSQL;  
insert into #tempdbfileusage  
EXEC SP_EXECUTESQL @TEMPDBSQL;  
  
  
/*********************/  
/****** Database Log Usage *********/  
/*********************/  
CREATE TABLE #LogSpace(  
DBName VARCHAR(100),  
LogSize VARCHAR(50),  
LogSpaceUsed_Percent VARCHAR(100),   
LStatus CHAR(1));  
  
INSERT INTO #LogSpace  
EXEC ('DBCC SQLPERF(LOGSPACE) WITH NO_INFOMSGS;');  
  
 
  
/*********************/  
/****** HTML Preparation *********/  
/*********************/  
  
DECLARE @TableHTML  VARCHAR(MAX),                                    
  @StrSubject VARCHAR(100),                                    
  @Oriserver VARCHAR(100),                                
  @Version VARCHAR(250),                                
  @Edition VARCHAR(100),                                
  @ISClustered VARCHAR(100),                                
  @SP VARCHAR(100),                                
  @ServerCollation VARCHAR(100),                                
  @SingleUser VARCHAR(5),                                
  @LicenseType VARCHAR(100),                                
  @Cnt int,           
  @URL varchar(1000),                                
  @Str varchar(1000),                                
  @NoofCriErrors varchar(3)       
  
-- Variable Assignment              
  
SELECT @Version = @@version                                
SELECT @Edition = CONVERT(VARCHAR(100), serverproperty('Edition'))                                
SET @Cnt = 0                                
IF serverproperty('IsClustered') = 0                                 
BEGIN                                
 SELECT @ISClustered = 'No'                                
END                                
ELSE        
BEGIN                                
 SELECT @ISClustered = 'YES'                                
END                                
SELECT @SP = CONVERT(VARCHAR(100), SERVERPROPERTY ('productlevel'))                                
SELECT @ServerCollation = CONVERT(VARCHAR(100), SERVERPROPERTY ('Collation'))                                 
SELECT @LicenseType = CONVERT(VARCHAR(100), SERVERPROPERTY ('LicenseType'))                                 
SELECT @SingleUser = CASE SERVERPROPERTY ('IsSingleUser')                                
      WHEN 1 THEN 'Yes'                                
      WHEN 0 THEN 'No'                                
      ELSE                                
      'null' END                                
SELECT @OriServer = CONVERT(VARCHAR(50), SERVERPROPERTY('servername'))                                  
SELECT @strSubject = 'Database Server Health Check ('+ CONVERT(VARCHAR(100), @SERVERNAME) + ')'                                    
   
  
  
SET @TableHTML =                                    
 '<font face="Verdana" size="4">Health Check</font>                                  
 <table border="1" cellpadding="0" cellspacing="0" style="border-collapse: collapse" bordercolor="#111111" width="47%" id="AutoNumber1" height="50">                                  
 <tr>                                  
 <td width="39%" height="22" bgcolor="#000080"><b>                           
 <font face="Verdana" size="2" color="#FFFFFF">Server Name</font></b></td>                                  
 </tr>                                  
 <tr>                                  
 <td width="39%" height="27"><font face="Verdana" size="2">' + @ServerName +'</font></td>                                  
 </tr>                                  
 </table>                                 
 <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="933" border="1">                                
 <tr>                                
 <td align="Center" width="50%" bgColor="#000080" height="15"><b>                                
 <font face="Verdana" color="#ffffff" size="1">Version</font></b></td>                                
 <td align="Center" width="17%" bgColor="#000080" height="15"><b>                                
 <font face="Verdana" color="#ffffff" size="1">Edition</font></b></td>                                
 <td align="Center" width="35%" bgColor="#000080" height="15"><b>                                
 <font face="Verdana" color="#ffffff" size="1">Service Pack</font></b></td>                                
 <td align="Center" width="60%" bgColor="#000080" height="15"><b>                                
 <font face="Verdana" color="#ffffff" size="1">Collation</font></b></td>                                
 <td align="Center" width="93%" bgColor="#000080" height="15"><b>                                
 <font face="Verdana" color="#ffffff" size="1">LicenseType</font></b></td>                                
 <td align="Center" width="40%" bgColor="#000080" height="15"><b>                                
<font face="Verdana" color="#ffffff" size="1">SingleUser</font></b></td>                                
 <td align="Center" width="93%" bgColor="#000080" height="15"><b>                                
 <font face="Verdana" color="#ffffff" size="1">Clustered</font></b></td>                                
 </tr>                                
 <tr>                                
 <td align="Center" width="50%" height="27"><font face="Verdana" size="1">'+@version +'</font></td>                                
 <td align="Center" width="17%" height="27"><font face="Verdana" size="1">'+@edition+'</font></td>                                
 <td align="Center" width="18%" height="27"><font face="Verdana" size="1">'+@SP+'</font></td>                                
 <td align="Center" width="17%" height="27"><font face="Verdana" size="1">'+@ServerCollation+'</font></td>                                
 <td align="Center" width="25%" height="27"><font face="Verdana" size="1">'+@LicenseType+'</font></td>                                
 <td align="Center" width="25%" height="27"><font face="Verdana" size="1">'+@SingleUser+'</font></td>                                
 <td align="Center" width="93%" height="27"><font face="Verdana" size="1">'+@isclustered+'</font></td>                                
 </tr>                                
 </table>                   
     
 <p style="margin-top: 0; margin-bottom: 0">&nbsp;</p>                                
 <font face="Verdana" size="4">SQL ErrorLog Summary in Last 24 Hours</font>' +                                    
 '<table style="BORDER-COLLAPSE: collapse" borderColor="#111111" cellPadding="0" width="933" bgColor="#ffffff" borderColorLight="#000000" border="1">                                  
 <tr>                                
 <td width="20%" bgColor="#000080" height="15"><b>                        
 <font face="Verdana" color="#ffffff" size="1">Number of Critical Errors</font></b></td>                                
 </tr>                                
 </table>                                
 <table style="BORDER-COLLAPSE: collapse" borderColor="#111111" cellPadding="0" width="933" bgColor="#ffffff" borderColorLight="#000000" border="1">                                  
 <tr>                                
 <td width="20%" bgColor="#000080" height="15"><b>                                
 <font face="Verdana" color="#ffffff" size="1">Error Log DateTime</font></b></td>                     
 <td width="80%" bgColor="#000080" height="15"><b>                                
 <font face="Verdana" color="#ffffff" size="1">Error Message</font></b></td>                                
 </tr>'                                
                
  
--SELECT                                 
-- @TableHTML = @TableHTML + '<tr>                                
-- <td width="20%" height="27"><font face="Verdana" size="1">'+ ISNULL(CONVERT(VARCHAR(50),LogDate ),'') +'</font></td>                                
-- <td width="80%" height="27"><font face="Verdana" size="1">'+ISNULL(CONVERT(VARCHAR(500),LogInfo ),'')+'</font></td>                                
-- </tr>'                                
--FROM  #ErrorLogInfo   ORDER BY      LogDate DESC   
  
  
 SELECT                                   
 @TableHTML = @TableHTML +                                     
 '</table>                                  
 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4">Instance last Recycled</font>                                  
 <table style="BORDER-COLLAPSE: collapse" borderColor="#111111" cellPadding="0" width="933" bgColor="#ffffff" borderColorLight="#000000" border="1">                                      
 <tr>                                      
 <th align="Center" width="50" bgColor="#000080">                                      
  <font face="Verdana" size="1" color="#FFFFFF">Last Recycle</font></th>                                      
 <th align="Center" width="50" bgColor="#000080">                                      
  <font face="Verdana" size="1" color="#FFFFFF">Current DateTime</font></th>                                      
 <th align="Center" width="50" bgColor="#000080">                                   
 <font face="Verdana" size="1" color="#FFFFFF">UpTimeInDays</font></th>                                      
  </tr>'                                  
                                  
SELECT                                   
 @TableHTML =  @TableHTML +                                       
 '<tr>                                    
 <td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), LastRecycle ), '')  +'</font></td>' +                                        
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  CurrentDate ), '')  +'</font></td>' +                                   
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  UpTimeInDays ), '')  +'</font></td>' +                                        
  '</tr>'                                  
FROM                                   
 #RebootDetails   
  
 
/** Free Disk Space Report ***/  
 
SELECT                                   
 @TableHTML = @TableHTML +                                   
 '</table>                          
 <p style="margin-top: 0; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4">Disk Space Report</font>' +                                      
 '<table style="BORDER-COLLAPSE: collapse" borderColor="#111111" cellPadding="0" width="933" bgColor="#ffffff" borderColorLight="#000000" border="1">                                    
 <tr>                                    
 <th align="left" width="30" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">DriveLetter</font></th>   
 <th align="left" width="30" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">FreeSpace_GB</font></th>                                    
 <th align="left" width="30" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">UsedSpace_GB</font></th>                                    
 <th align="left" width="30" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">TotalSpace_GB</font></th>
<th align="left" width="30" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Percentage_Free</font></th>                                                                 
 </tr>'                                    
                                  
SELECT                                   
 @TableHTML = @TableHTML +   
 CASE WHEN Percentage_Free < 10 THEN
   '<tr bgcolor="#ffe6e6">'
ELSE
'<tr>'
END +
'<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(10), DriveLetter),'') + '</font></td>' +                       
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(50), FreeSpace_GB),'') + '</font></td>' +                                  
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(50), UsedSpace_GB),'') +'</font></td>' +     
  '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(max), TotalSpace_GB),'') +'</font></td>' +
--'<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(max), Percentage_Free),'') +'</font></td></tr>'
CASE WHEN Percentage_Free < 10 THEN
  '<td align="Center"><font face="Verdana" size="1" color="#FF0000"><b>' + ISNULL(CONVERT(VARCHAR(100),  Percentage_Free), '')  +'</font></td>'
ELSE
  '<td align="Center"><font face="Verdana" size="1" color="#40C211"><b>' + ISNULL(CONVERT(VARCHAR(100),  Percentage_Free), '')  +'</font></td>'
  END +
  '</tr>'
FROM ##temp
 
  
/** Tempdb File Usage ***/  
SELECT                                   
 @TableHTML =  @TableHTML +                              
 '</table>                                  
 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4">Tempdb File Usage</font>                                  
 <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="933" border="1">                                  
   <tr>                
 <th align="Center" width="300" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Database Name</font></th>               
 <th align="Center" width="300" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">File Name</font></th>               
 <th align="Center" width="250" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Physical Name</font></th>               
 <th align="Center" width="250" bgColor="#000080">                                
 <font face="Verdana" size="1" color="#FFFFFF">FileSize MB</font></th>               
 <th align="Center" width="200" bgColor="#000080">               
 <font face="Verdana" size="1" color="#FFFFFF">Available MB</font></th>               
 <th align="Center" width="200" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Percent_full </font></th>               
   </tr>'                                  
select                                   
@TableHTML =  @TableHTML +                                     
 '<tr>' +                                      
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(databasename, '') + '</font></td>' +                                      
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(FileName, '') +'</font></td>' +                                      
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(physicalName, '') +'</font></td>' +                                      
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(filesizeMB, '') +'</font></td>' +                                  
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(availableSpaceMB, '') +'</font></td>' +  
 CASE WHEN CONVERT(DECIMAL(10,3),percentfull) >80.00 THEN    
'<td align="Center"><font face="Verdana" size="1" color="#FF0000"><b>' + ISNULL(percentfull, '') +'</b></font></td></tr>'                                               
 ELSE  
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(percentfull, '') +'</font></td></tr>' END                                
from                                   
 #tempdbfileusage       
  
  
/** CPU Usage ***/  
SELECT                                   
 @TableHTML =  @TableHTML +                              
 '</table>                                  
 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4">CPU Usage Currently</font>                                  
 <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="933" border="1">                                  
   <tr>                
 <th align="Center" width="300" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">System Time</font></th>               
 <th align="Center" width="300" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">SQLProcessUtilization</font></th>               
 <th align="Center" width="250" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">SystemIdle</font></th>               
 <th align="Center" width="250" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">OtherProcessUtilization</font></th>               
 <th align="Center" width="200" bgColor="#000080">               
 <font face="Verdana" size="1" color="#FFFFFF">load DateTime</font></th>               
   </tr>'                                  
SELECT                                   
 @TableHTML =  @TableHTML +                                     
 '<tr>' +                                      
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), EventTime2 ), '')  +'</font></td>' +    
  '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), SQLProcessUtilization ), '')  +'</font></td>' +    
   '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), SystemIdle ), '')  +'</font></td>' +                              
   '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), OtherProcessUtilization ), '')  +'</font></td>' +                              
  '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), load_date ), '')  +'</font></td> </tr>'                                  
FROM                                   
 #CPU   
  
/** Memory Usage ***/  
SELECT                                   
 @TableHTML =  @TableHTML +                              
 '</table>                                  
 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4">Memory Usage </font>                                  
 <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="933" border="1">                                  
   <tr>                
 <th align="left" width="136" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Parameter</font></th>                              
  <th align="left" width="200" bgColor="#000080">               
 <font face="Verdana" size="1" color="#FFFFFF">Value</font></th>              
   </tr>'                                  
SELECT                                   
 @TableHTML =  @TableHTML +                                       
 '<tr>                                    
 <td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(200),  Parameter ), '')  +'</font></td>' +                                        
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  Value ), '')  +'</font></td>' +                                     
  '</tr>'                                  
FROM                                   
 #Memory;   
  
/** Performance Counter Values ***/  
SELECT                                   
 @TableHTML =  @TableHTML +                              
 '</table>                                  
 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4">Performance Counter Data</font>                                  
 <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="933" border="1">                                  
   <tr>                
 <th align="left" width="136" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Performance_Counter</font></th>                              
  <th align="left" width="200" bgColor="#000080">               
 <font face="Verdana" size="1" color="#FFFFFF">Value</font></th>              
   </tr>'                                  
SELECT                                   
 @TableHTML =  @TableHTML +                                       
 '<tr>                                    
 <td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(300),  Parameter ), '')  +'</font></td>' +                                        
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  Value ), '')  +'</font></td>' +                                     
  '</tr>'                                  
FROM                                   
 #PerfCntr_Data;   
   
/** Database Backup Report ***/  
SELECT                                   
 @TableHTML =  @TableHTML +                              
 '</table>                                  
 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4">Missing Backup Report</font>                                  
 <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="933" border="1">                                  
   <tr>                
 <th align="left" width="136" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Database_Name</font></th>                              
  <th align="left" width="200" bgColor="#000080">               
 <font face="Verdana" size="1" color="#FFFFFF">Last_Backup_Date</font></th>              
   </tr>'                                  
SELECT      
 @TableHTML =  @TableHTML +                                       
 '<tr>                                    
 <td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  Database_Name ), '')  +'</font></td>' +                                        
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  Last_Backup_Date), '')  +'</font></td>' +                                     
  '</tr>'                                  
FROM             
 #Backup_Report  
  
 /** Connection Information ***/  
  
       
      
/** Log Space Usage ***/  
SELECT                                   
 @TableHTML =  @TableHTML +                              
 '</table>                                  
 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4">Log Space Usage </font>                                  
 <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="933" border="1">                                  
   <tr>                
 <th align="left" width="136" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">DatabaseName</font></th>                              
  <th align="left" width="200" bgColor="#000080">               
 <font face="Verdana" size="1" color="#FFFFFF">Log_Space_Used</font></th>                              
  <th align="left" width="200" bgColor="#000080">               
 <font face="Verdana" size="1" color="#FFFFFF">Log_Usage_%</font></th>              
   </tr>'                                  
SELECT                                   
 @TableHTML =  @TableHTML +                                       
  '<tr>                                    
 <td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  DBName ), '')  +'</font></td>' +                                        
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  LogSize ), '')  +'</font></td>' +   
 CASE WHEN CONVERT(DECIMAL(10,3),LogSpaceUsed_Percent) >80.00 THEN  
  '<td><font face="Verdana" size="1" color="#FF0000"><b>' + ISNULL(CONVERT(VARCHAR(100),  LogSpaceUsed_Percent ), '')  +'</b></font></td>'  
 ELSE  
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  LogSpaceUsed_Percent ), '')  +'</font></td>'   
 END +                                     
  '</tr>'                               
FROM                                   
 #LogSpace   
 
 /**Failed Jobs in Last 24Hrs****/
 
SELECT                                   
 @TableHTML = @TableHTML +                                   
 '</table>                          
 <p style="margin-top: 0; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4">Failed Jobs in Last 24Hrs</font>' +                                      
 '<table style="BORDER-COLLAPSE: collapse" borderColor="#111111" cellPadding="0" width="933" bgColor="#ffffff" borderColorLight="#000000" border="1">                                    
 <tr>                                    
 <th align="left" width="430" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">date_time</font></th>   
 <th align="left" width="70" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">job_name</font></th>                                    
 <th align="left" width="85" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">job_step</font></th>                                   
 <th align="left" width="183" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">error_message</font></th>                                                                    
 </tr>'                                    
                                  
SELECT                                   
 @TableHTML = @TableHTML +                                      
'<tr><td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(50), date_time),'') + '</font></td>' +                       
 '<td><font face="Verdana" size="1" color="#FF0000">' + ISNULL(CONVERT(VARCHAR(50), job_name),'') + '</font></td>' +                                  
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(50), job_step),'') +'</font></td>' +     
  '<td><font face="Verdana" size="1" color="#FF0000">' + ISNULL(CONVERT(VARCHAR(max), error_message),'') +'</font></td></tr>'      
FROM #Failed_jobs
  
  
/*** Job Info ****/  
SELECT                                   
 @TableHTML = @TableHTML +                                   
 '</table>                          
 <p style="margin-top: 0; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4">Job Status</font>' +                                      
 '<table style="BORDER-COLLAPSE: collapse" borderColor="#111111" cellPadding="0" width="933" bgColor="#ffffff" borderColorLight="#000000" border="1">                                    
 <tr>                                    
 <th align="left" width="430" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">spid</font></th>   
 <th align="left" width="70" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">latwaittype</font></th>                                    
 <th align="left" width="85" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">dbname</font></th>                                    
 <th align="left" width="183" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Process Login time</font></th>                                    
 <th align="left" width="136" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">status</font></th>                                    
 <th align="left" width="136" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">opentran</font></th>      
  <th align="left" width="136" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">hostname</font></th>    
  <th align="left" width="146" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">JobName</font></th>    
  <th align="left" width="136" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">command</font></th>    
  <th align="left" width="136" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">domain</font></th>     
   <th align="left" width="136" bgColor="#000080">                                    
 <font face="Verdana" size="1" color="#FFFFFF">LoginName</font></th>                                 
 </tr>'                                    
                                  
SELECT                                   
 @TableHTML = ISNULL(CONVERT(VARCHAR(MAX), @TableHTML), 'No Job Running') + '<tr><td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), spid), '') +'</font></td>' +                                      
'<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(50), lastwaittype),'') + '</font></td>' +                       
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(50), dbname),'') + '</font></td>' +                                  
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(50), login_time),'') +'</font></td>' +     
  '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(50), status),'') +'</font></td>' +     
   '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(50), opentran),'') +'</font></td>' +     
    '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(50), hostname),'') +'</font></td>' +     
     '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(500), JobName),'') +'</font></td>' +     
      '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(200), command),'') +'</font></td>' +     
        '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(50), domain),'') +'</font></td>' +     
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(50),loginname ),'') + '</font></td></tr>'      
FROM                                   
 #JobInfo  
  
   
   
 /** Blocking Information **/  
  
 
  
/** Long running Transactions***/  
 
    
EXEC msdb.dbo.sp_send_dbmail                                    
 @profile_name = @MailProfile,                       
 @recipients=@MailID,                                   
 @subject = @strSubject,                                   
 @body = @TableHTML,                                      
 @body_format = 'HTML' ;                               
  
  
DROP TABLE  #RebootDetails  
--DROP TABLE  #ErrorLogInfo  
DROP TABLE  #CPU  
DROP TABLE  #Memory_BPool;  
DROP TABLE  #Memory_sys;  
DROP TABLE  #Memory_process;  
DROP TABLE  #Memory;  
DROP TABLE  #perfmon_counters;  
DROP TABLE  #PerfCntr_Data;  
DROP TABLE  #Backup_Report;  
DROP TABLE  #JobInfo;  
DROP TABLE  #tempdbfileusage;  
DROP TABLE  #LogSpace;  
DROP TABLE  #Failed_jobs;
DROP TABLE ##_DriveSpace;
DROP TABLE ##_DriveInfo;
DROP TABLE ##temp;
  
SET NOCOUNT OFF;  
SET ARITHABORT OFF;  
END  
 

GO

/*
DECLARE @RC int
DECLARE @MailProfile nvarchar(200)
DECLARE @MailID nvarchar(2000)
DECLARE @Server varchar(100)
 
-- TODO: Set parameter values here.
 
EXECUTE @RC = [DBADB].[dbo].[SQLhealthcheck_report]
 'DBA'
,'Support@mail.com' 
,''
GO
*/
