--check for execution plan and query id using query text
SELECT 
    qsq.query_id,
    qsqt.query_text_id,
    qsqt.query_sql_text AS QueryText,
   -- qsr.total_duration / 1000 AS TotalExecutionTimeSecs,  -- seconds
   -- qsr.execution_count,
    qsr.last_execution_time,
    qsp.query_plan
FROM 
    sys.query_store_query_text AS qsqt
JOIN 
    sys.query_store_query AS qsq
        ON qsqt.query_text_id = qsq.query_text_id
JOIN 
    sys.query_store_plan AS qsp
        ON qsq.query_id = qsp.query_id
JOIN 
    sys.query_store_runtime_stats AS qsr
        ON qsp.plan_id = qsr.plan_id
WHERE 
    qsr.last_execution_time > DATEADD(HOUR, -2, GETDATE())
    AND qsqt.query_sql_text LIKE 'WITH FilteredOutlets%'
ORDER BY 
    qsr.last_execution_time DESC;


for the particular id,using this query we can get plan
SELECT 
    qsq.query_id,
    qsp.plan_id,
    CAST(qsp.query_plan AS XML) AS ExecutionPlan
FROM sys.query_store_plan qsp
JOIN sys.query_store_query qsq
    ON qsp.query_id = qsq.query_id
WHERE qsq.query_id =52767984;

Store procedure
--  SELECT
--    qs.execution_count,
--    qs.total_elapsed_time / qs.execution_count AS avg_elapsed_time,
--    qp.query_plan
--FROM sys.dm_exec_procedure_stats qs
--CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
--WHERE OBJECT_NAME(qs.object_id, qs.database_id)
--      = 'Spcreate_ClientDPAccountCodes_For_FundsGenie';



SELECT
    q.query_id,
    q.object_id,
    OBJECT_SCHEMA_NAME(q.object_id) AS SchemaName,
    OBJECT_NAME(q.object_id) AS ProcedureName,
    q.query_parameterization_type_desc,
    qt.query_sql_text
FROM sys.query_store_query AS q
JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id
WHERE q.object_id = OBJECT_ID
      ('SPARCIM.dbo.Sparc_SPPullClientsFromSPARCToGateWay')
ORDER BY q.query_id;