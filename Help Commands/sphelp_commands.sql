--help commands
Exec sp_helpdb 'AdventureWorksDW2022'

Exec sp_helpfile

exec sp_spaceused '[dbo].[test_under]'

exec sp_help 'dbo.ApiRequestLogs'

exec sp_helpindex '[dbo].[tbl_ads2shistory]'


SELECT name
FROM sys.stats
WHERE object_id = OBJECT_ID('dbo.updatetest');
