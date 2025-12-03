USE [DBADB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[TableSizeData](
	[DBID] [int] NULL,
	[DBNAME] [varchar](200) NULL,
	[TableName] [varchar](200) NULL,
	[SchemaName] [varchar](200) NULL,
	[rows] [bigint] NULL,
	[TotalSpaceKB] [bigint] NULL,
	[TotalSpaceMB] [float] NULL,
	[UsedSpaceKB] [bigint] NULL,
	[UsedSpaceMB] [float] NULL,
	[UnusedSpaceKB] [bigint] NULL,
	[UnusedSpaceMB] [float] NULL,
	[Date] [date] NULL
) ON [PRIMARY]
GO



insert into DBADB.dbo.TableSizeData
exec sp_MSforeachdb 'USE [?]

SELECT 
db_id(),
db_name(),
    t.NAME AS TableName,
    s.Name AS SchemaName,
    p.rows,
    SUM(a.total_pages) * 8 AS TotalSpaceKB, 
    CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS TotalSpaceMB,
    SUM(a.used_pages) * 8 AS UsedSpaceKB, 
    CAST(ROUND(((SUM(a.used_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS UsedSpaceMB, 
    (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB,
    CAST(ROUND(((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024.00, 2) AS NUMERIC(36, 2)) AS UnusedSpaceMB,
	getdate()
FROM 
    sys.tables t
INNER JOIN      
    sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN 
    sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN 
    sys.allocation_units a ON p.partition_id = a.container_id
LEFT OUTER JOIN 
    sys.schemas s ON t.schema_id = s.schema_id
WHERE 
    t.NAME NOT LIKE ''dt%'' 
    AND t.is_ms_shipped = 0
    AND i.OBJECT_ID > 255 
GROUP BY 
    t.Name, s.Name, p.Rows
ORDER BY 
    TotalSpaceMB DESC, t.Name'



declare @sql table(server varchar(50),DBName varchar(50),TableName varchar(100),size2 decimal(10,2),size1 decimal(10,2),difference varchar(50))

insert into @sql

SELECT top 15 @@SERVERNAME   ,
a.DBName  ,
a.tablename  ,
b.size2  ,
a.size1 ,
(cast(cast(((a.size1 - b.size2)/b.size2 * 100) as decimal(18,2)) as varchar(100)) +' %') AS 'td'
FROM (SELECT top 15 DBName,tablename,sum(TotalSpaceMB) as size1  from [DBADB].[dbo].[TableSizeData]
where  Date=cast(GETDATE() as date) group by DBName,tablename order by sum(TotalSpaceMB) desc ) as a
inner join 
(SELECT top 15 DBName ,tableName ,sum(TotalSpaceMB) as size2 from [DBADB].[dbo].[TableSizeData]  where Date=cast(GETDATE()-1 as date) 
group by DBName,tablename order by sum(TotalSpaceMB) desc  ) as b 
on  a.DBName=b.DBName 
where a.DBName not in ('master','model','distribution','DBADB','ReportServer','ReportServerTempDB') and a.TableName=b.TableName
order by size2 desc

SET NOCOUNT ON
DECLARE  @xml nvarchar(max)
SELECT @xml = Cast(( SELECT top 10 server AS 'td',
'' ,
DBName  AS 'td',
'' ,
tablename  AS 'td',
'',
size2   AS 'td',
'',
size1  AS 'td',
'' ,
difference as 'td',''
from @sql order by difference desc

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
		Table Size Growth Report
		</H2>
		<table> 
			<tr>
				<th> Server </th> <th>Database Name</th> <th>tableName</th> <th>Yesterday Table Size(MB)</th><th>Today Table Size(MB)</th> <th>Difference</th>   
			</tr>'
			SET @body = @body + @xml + '
		</table>
	</body>
</html>'
if(@xml is not null)
BEGIN
EXEC msdb.dbo.Sp_send_dbmail
@profile_name = 'DBA',--Change
@body = @body,
@body_format ='html',
@recipients = '',
@copy_recipients ='',
@blind_copy_recipients='',
@subject = 'Client Name Table Size Growth Report: ServerName'; --Change
END


