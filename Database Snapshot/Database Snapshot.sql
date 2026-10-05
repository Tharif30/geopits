
Create database snapshot_demo;

use snapshot_demo;

Create table test123(col1 varchar(50),col2 int,col3 int);
Create table test1(col1 varchar(50),col2 int,col3 int);
Create table test12(col1 varchar(50),col2 int,col3 int);

insert into test1 values('Before snapshot',1,23)
insert into test1 values('Before snapshot',2,24)
insert into test1 values('Before snapshot',3,25)

insert into test12 values('Before snapshot',1,23)
insert into test12 values('Before snapshot',2,24)
insert into test12 values('Before snapshot',3,25)

insert into test123 values('Before snapshot',1,23)
insert into test123 values('Before snapshot',2,24)
insert into test123 values('Before snapshot',3,25)


select * from  test1        
select * from  test12               
select * from  test123


use snapshot_demo;
select name,create_date from sys.tables --3 tables


--commands to extract page level information
--to find page details of a table or data
dbcc ind('snapshot_demo',test1 ,-1) -- 2 pages
dbcc ind('snapshot_demo',test12 ,-1)  -- 2 pages
dbcc ind('snapshot_demo',test123 ,-1)  -- 2 pages
--actual page content 
DBCC TRACEON(3604)
DBCC PAGE('snapshot_demo',1,391,3) WITH TABLERESULTS --[0|1|2|3] display option
GO


USE master;
GO

SELECT
    name AS LogicalFileName,
    physical_name
FROM sys.master_files
WHERE database_id = DB_ID('snapshot_demo');
GO

--If the database has multiple data files, each data file must have a corresponding snapshot file:
CREATE DATABASE Demosnapshot
ON
(
    NAME = snapshot_demo,
    FILENAME = 'C:\Users\Public\Demosnapshot.ss'
)
AS SNAPSHOT OF snapshot_demo;
GO

select * from Demosnapshot..test123

select * from snapshot_demo..test123

DBCC PAGE ('Demosnapshot', 1, 100, 3);
