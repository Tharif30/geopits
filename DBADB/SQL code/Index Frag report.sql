USE [DBADB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[IndexFragData](
	[DBName] [varchar](100) NULL,
	[Schemaname] [varchar](100) NULL,
	[Tablename] [varchar](200) NULL,
	[Index_Desc] [varchar](100) NULL,
	[Indexname] [varchar](200) NULL,
	[FragPercentage] [float] NULL,
	[IndexSizeKB] [bigint] NULL,
	[page_count] [bigint] NULL,
	[FragDate] [date] NULL
) ON [PRIMARY]
GO


--IndexFrag collection code

insert into [DBADB].dbo.[IndexFragData]
exec sp_MSforeachdb 'USE [?]

SELECT db_name(ps.database_id) AS DBName,
         S.name AS Schemaname,
         object_name(ps.OBJECT_ID) AS Tablename,
         Index_Description = CASE
                           WHEN ps.index_id = 1 THEN ''Clustered Index''
                           WHEN ps.index_id <> 1 THEN ''Non-Clustered Index''
                             END,
         b.name AS Indexname,
         ROUND(ps.avg_fragmentation_in_percent,0,1) AS ''Fragmentation%'',
         SUM(page_count*8) AS ''IndexSizeKB'',
         ps.page_count,
		 CONVERT(DATE, GETDATE())
   FROM sys.dm_db_index_physical_stats (DB_ID(),NULL,NULL,NULL,NULL) AS ps
   INNER JOIN sys.indexes AS b ON ps.object_id = b.object_id AND ps.index_id = b.index_id AND b.index_id <> 0 -- heap not required
   INNER JOIN sys.objects AS O ON O.object_id=b.object_id AND O.type=''U'' AND O.is_ms_shipped=0 -- only user tables
   INNER JOIN sys.schemas AS S ON S.schema_Id=O.schema_id
   WHERE ps.database_id = DB_ID() AND ps.avg_fragmentation_in_percent > 0 -- Indexes having more than 60% fragmentation
   GROUP BY db_name(ps.database_id),S.name,object_name(ps.OBJECT_ID),CASE WHEN ps.index_id = 1 THEN ''Clustered Index'' WHEN ps.index_id <> 1 THEN ''Non-Clustered Index'' END,b.name,ROUND(ps.avg_fragmentation_in_percent,0,1),ps.avg_fragmentation_in_percent,ps.page_count
   ORDER BY ps.avg_fragmentation_in_percent DESC
'
go

---------Index Report code
use DBADB
go
set nocount on;
IF OBJECT_ID('tempdb.dbo. #fragdata', 'U') IS NOT NULL
    DROP TABLE  #fragdata;
--drop table if exists #fragdata
CREATE TABLE #fragdata 
( 
  [DB Name]  varchar(64),
  [Table Name] varchar(128),
  [Index Name] varchar(128),
  [Fragmentation %] decimal(5,2)
)

declare @page_count_threshold int = 1000; --default value is 1000
declare @frag_percent_threshold int = 30;
declare @date_of_frag date = convert(date, GETDATE()-1); -- for previous day
INSERT INTO #fragdata
select DBName, Tablename, Indexname, FragPercentage
from [dbo].[IndexFragData]
where FragDate =  @date_of_frag
and FragPercentage > @frag_percent_threshold
and page_count > @page_count_threshold
select * from #fragdata

DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST((SELECT 
[DB Name] AS 'td',' ',
[Table Name] AS 'td',' ',
[Index Name] AS 'td',' ',
[Fragmentation %] AS 'td'
FROM #fragdata
ORDER BY [Fragmentation %] desc 
FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))

SET @body ='<html><head>
		<style>
			table, td ,th
			{
				border: 1px solid black;
				border-collapse: collapse;
				text-align: center;
			}			
		</style>
	</head><body><H3>Fragmentation Statistics for '+cast(@date_of_frag as varchar(10))+' </H3>
<table> 
<tr>
<th> DB Name </th> <th> Table Name </th> <th> Index Name </th> <th> Fragmentation % </th></tr>'    

SET @body = @body + @xml +'</table>
<br><br>The above indexes need to be rebuilt.<br>Please let us know if we can get proceed with the same.
<br><br>Thanks,
<br> MS SQL Team
</body></html>' --Change Team

print @body

EXEC msdb.dbo.sp_send_dbmail
@profile_name = 'DBA', 
@body = @body,
@body_format ='HTML',
@recipients = '',
@copy_recipients = '',
@blind_copy_recipients ='',
@subject = 'Client Name SQL Server Fragmentation Report : ServerName' ;

set nocount off