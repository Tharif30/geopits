SELECT

 qst.query_sql_text,

 qrs.execution_type,

 qrs.execution_type_desc,

 qpx.query_plan_xml,

 qrs.count_executions,

 qrs.last_execution_time

FROM sys.query_store_query AS qsq

JOIN sys.query_store_plan AS qsp on qsq.query_id=qsp.query_id

JOIN sys.query_store_query_text AS qst on qsq.query_text_id=qst.query_text_id

OUTER APPLY (SELECT TRY_CONVERT(XML, qsp.query_plan) AS query_plan_xml) AS qpx

JOIN sys.query_store_runtime_stats qrs on qsp.plan_id = qrs.plan_id

WHERE qrs.execution_type =3

ORDER BY qrs.last_execution_time DESC;

GO