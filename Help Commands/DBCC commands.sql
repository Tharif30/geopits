
--to clean plan cache
dbcc freeproccache()

--commnad to clear bufferpool
CHECKPOINT;
DBCC DROPCLEANBUFFERS;

--oldest active transaction
DBCC OPENTRAN

--commands to extract page level information
--to find page details of a table or data
dbcc ind('DBADB',test_under,-1)

--actual page content 
DBCC TRACEON(3604)
DBCC PAGE('DBADB',1,102021,3) WITH TABLERESULTS --[0|1|2|3] display option
GO

