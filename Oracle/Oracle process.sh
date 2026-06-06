--Oracle process
ps -ef | grep pmon

ps -ef | grep smon

ps -ef | grep TCSCENTR

--oracle process
ps -ef | grep ora_


--process info 
ps -fp 123434

--server restart time
who -b

--ram info
svmon -g

--top ram consuming
svmon -P | head -20  

--process ram info 
svmon -P 12324


--listener status and start
lsnrctl start
lsnrctl status


-awr report
@?/rdbms/admin/awrrpt.sql
--ash report
@?/rdbms/admin/ashrpt.sql
date format
05/17/26 12:00



 select open_mode, database_role from v$database;
