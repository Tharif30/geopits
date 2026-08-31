SELECT [Current LSN],
       [Operation],
       [Transaction Name],
       [Transaction ID],
       [Transaction SID],
       [SPID],
       [Begin Time]
 FROM   fn_dblog(null,null)


 SELECT
 [Current LSN],
 [Transaction ID],
 [Operation],
 [Transaction Name],
 [SPID],
 [CONTEXT],
 [AllocUnitName],
 [Page ID],
 [Slot ID],
 [Begin Time],
 [End Time],
 [Number of Locks],
 [Lock Information]
FROM sys.fn_dblog(NULL,NULL)
WHERE Operation ='LOP_MODIFY_ROW'
--IN 
   ('LOP_INSERT_ROWS','LOP_MODIFY_ROW',
    'LOP_DELETE_ROWS','LOP_BEGIN_XACT','LOP_COMMIT_XACT')  
    order by [Begin Time] desc



--fn_full_dblog

SELECT TOP (100) *
FROM sys.fn_full_dblog
(
    NULL,       -- @start
    NULL,       -- @end
    DB_ID(),    -- @dbid
    NULL,       -- @logical_dbid
    NULL,       -- @backup_account
    NULL,       -- @backup_container
    NULL,       -- @page_fid
    NULL,       -- @page_pid
    'DEFAULT',  -- @init_prev_page_lsn
    NULL,       -- @xdes_id_high
    NULL        -- @xdes_id_low
);


