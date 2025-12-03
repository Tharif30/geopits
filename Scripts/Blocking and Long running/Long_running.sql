create database shrink

use shrink

create table shrink_table(val int ,val2 int)

insert into shrink_table 
select * from shrink_table where val=13

create table pri(val int primary key,val2 int)
insert into shrink_table values(34,32);

insert into shrink_table values(34,12)
insert into shrink_table values(13,14)

delete from shrink_table where val=34

WAITFOR DELAY '00:01:10'

SELECT TOP 20
est.TEXT AS QUERY ,
Db_name(dbid),
eqs.execution_count AS EXEC_CNT,
eqs.max_elapsed_time AS MAX_ELAPSED_TIME,
ISNULL(eqs.total_elapsed_time / NULLIF(eqs.execution_count,0), 0) AS AVG_ELAPSED_TIME,
eqs.creation_time AS CREATION_TIME,
ISNULL(eqs.execution_count / NULLIF(DATEDIFF(s, eqs.creation_time, GETDATE()),0), 0) AS EXEC_PER_SECOND,
total_physical_reads AS AGG_PHYSICAL_READS
FROM sys.dm_exec_query_stats eqs
CROSS APPLY sys.dm_exec_sql_text( eqs.sql_handle ) est
ORDER BY
eqs.max_elapsed_time DESC