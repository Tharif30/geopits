--spid consuming the Tempdb usage
USE tempdb;
GO
SELECT 
    session_id,
    SUM(internal_objects_alloc_page_count) * 8 AS InternalKB,
    SUM(user_objects_alloc_page_count) * 8 AS UserKB
FROM sys.dm_db_session_space_usage
GROUP BY session_id
ORDER BY InternalKB DESC;

--total tempdb usage 
--version store
SELECT GETDATE() AS runtime,
    SUM(user_object_reserved_page_count) * 8 AS usr_obj_kb,
    SUM(internal_object_reserved_page_count) * 8 AS internal_obj_kb,
    SUM(version_store_reserved_page_count) * 8 AS version_store_kb,
    SUM(unallocated_extent_page_count) * 8 AS freespace_kb,
    SUM(mixed_extent_page_count) * 8 AS mixedextent_kb
FROM sys.dm_db_file_space_usage;


--temp usage and query text for particular spid 
--query text
SELECT t.text AS QueryText
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.session_id IN (164, 167);

--usage
USE tempdb;
SELECT session_id,
       SUM(internal_objects_alloc_page_count + user_objects_alloc_page_count) * 8 AS UsedKB
FROM sys.dm_db_session_space_usage
WHERE session_id IN (164, 167)
GROUP BY session_id;


