--Create DB_Meta table in DBADB Database
USE [DBADB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[DB_Meta](
	[Instance_Name] [varchar](100) NULL,
	[Database_Names] [varchar](100) NULL,
	[Dates] [date] NULL,
	[Size MB] [decimal](10, 2) NULL
) ON [PRIMARY]
GO

---------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------- Database size report  Job step code --------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------


DECLARE @SNAME VARCHAR(100),@subjectcont nvarchar(512)='Client Name '+@@Servername+ ' Database Size Report' ;  --Change
DECLARE DB_CURSOR CURSOR FOR SELECT @@SERVERNAME 
OPEN DB_CURSOR
FETCH DB_CURSOR INTO @SNAME
WHILE @@FETCH_STATUS = 0
BEGIN
	DECLARE @NAME varchar(100)
	declare @var2 table (Name varchar(300))
	declare @var1 nvarchar(3000)
	DECLARE @VAR3 nvarchar(50)
	SELECT @VAR3 = @@SERVERNAME
		IF(@SNAME != @VAR3) 
		BEGIN
	select @var1 ='select * from openquery('+@SNAME+',''select name from sys.sysdatabases where [name] <> ''test'''')'
	insert into @var2 exec sp_executesql @var1
	DECLARE @INSNAME table(InstanceName varchar(100))
	DECLARE @VAR nvarchar(500)
	SET @VAR = 'select * from openquery('+@SNAME+',''SELECT @@SERVERNAME'')'
	insert into @INSNAME exec sp_executesql @VAR
	END
	ELSE
	BEGIN 
	INSERT into @var2 select name from sys.sysdatabases where [name] <> 'test'
	INSERT into @INSNAME select @@SERVERNAME
	End
DECLARE DB_CURSOR1 CURSOR FOR select Name from @var2
	OPEN DB_CURSOR1
	FETCH DB_CURSOR1 INTO @NAME
	WHILE @@FETCH_STATUS = 0
		BEGIN
			declare @cmd nvarchar(1000)
			DECLARE @SQL TABLE (databasename varchar(100),Size varchar(100))
			insert into @SQL exec ('['+@NAME+'].dbo.sp_executesql N''SELECT db_name() AS [Database Name],
			SUM(CAST(size AS DECIMAL(18,2))/128.0) AS [DatabaseSize MB]
			FROM ['+@NAME+'].sys.sysfiles''')
			insert into DBADB.dbo.DB_Meta select (select InstanceName from @INSNAME),databasename,GETDATE(),Size from @SQL
			delete from @SQL
			FETCH  DB_CURSOR1 INTO @NAME
		END
	CLOSE DB_CURSOR1
	DEALLOCATE DB_CURSOR1
	delete from @var2
	delete from @INSNAME
	FETCH  DB_CURSOR INTO @SNAME		
END
CLOSE DB_CURSOR
DEALLOCATE DB_CURSOR
--Send Table in HTML
SET NOCOUNT ON
DECLARE  @xml nvarchar(max)
SELECT @xml = Cast((SELECT a.Instance_Name AS 'td',
'',
a.Database_Names AS 'td',
'',
b.size2 AS 'td',
'',
a.size1 AS 'td',
'',
(cast(cast(((a.size1 - b.size2)/b.size2 * 100) as decimal(18,2)) as varchar(100)) +' %') AS 'td'
FROM (SELECT Database_Names,Instance_Name,[Size MB] as size1 from DBADB.dbo.DB_Meta
where Dates=cast(GETDATE() as date)) as a
inner join 
(SELECT Database_Names,Instance_Name,[Size MB] as size2 from DBADB.dbo.DB_Meta where Dates=cast(GETDATE()-1 as date)) as b 
on  a.Database_Names=b.Database_Names and a.Instance_Name=b.Instance_Name 
where a.Database_Names not in ('master','model','distribution','DBADB','ReportServer','ReportServerTempDB')
order by a.Instance_Name
FOR xml path('tr'), elements) AS NVARCHAR(max))
Declare @body nvarchar(max)
SET @body =
'<html>
	<head>
		<style>
			table, th, td 
			{
				border: 1px solid black;
				border-collapse: collapse;
				text-align: center;
			}
		</style>
	</head>
	<body>
		<H2>
		Database Size Report
		</H2>
		<table> 
			<tr>
				<th> Server </th> <th>Database Name</th> <th>Yesterday DB Size(MB)</th><th>Today DB Size(MB)</th> <th>Difference</th>   
			</tr>'
			SET @body = @body + @xml + '
		</table>
	</body>
</html>'
if(@xml is not null)
BEGIN
EXEC msdb.dbo.Sp_send_dbmail
@profile_name = '', --Change
@body = @body,
@body_format ='html',
@recipients = '', --Change
--@blind_copy_recipients='',
@subject = @subjectcont;
END
SET NOCOUNT OFF


--Job step code end



