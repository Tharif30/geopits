USE [DBADB]
GO

/****** Object:  Table [dbo].[TableSizeData]    Script Date: 1/3/2025 1:22:53 PM ******/
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