WITH BlockingSessions AS
(
    SELECT DISTINCT
           CAST(blocking_session_id AS INT) AS session_id
    FROM sys.dm_exec_requests
    WHERE blocking_session_id > 0
),
BlockingTree AS
(
    -----------------------------------------------------------------------
    -- Head Blockers
    -----------------------------------------------------------------------
    SELECT
        CAST(bs.session_id AS INT) AS session_id,
        CAST(0 AS INT) AS blocking_session_id,
        CAST(RIGHT('0000' + CAST(bs.session_id AS VARCHAR(10)),4) AS VARCHAR(4000)) AS sort_path,
        CAST(CAST(bs.session_id AS VARCHAR(10)) AS VARCHAR(4000)) AS display_path,
        CAST(0 AS INT) AS lvl
    FROM BlockingSessions bs
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.dm_exec_requests r
        WHERE r.session_id = bs.session_id
          AND r.blocking_session_id > 0
    )

    UNION ALL

    -----------------------------------------------------------------------
    -- Blocked Sessions
    -----------------------------------------------------------------------
    SELECT
        CAST(r.session_id AS INT),
        CAST(r.blocking_session_id AS INT),

        CAST(
            bt.sort_path + '.' +
            RIGHT('0000' + CAST(r.session_id AS VARCHAR(10)),4)
            AS VARCHAR(4000)
        ),

        CAST(
            bt.display_path + ' -> ' +
            CAST(r.session_id AS VARCHAR(10))
            AS VARCHAR(4000)
        ),

        bt.lvl + 1

    FROM sys.dm_exec_requests r
    INNER JOIN BlockingTree bt
        ON r.blocking_session_id = bt.session_id
)

SELECT

    CASE
        WHEN bt.lvl = 0
            THEN 'HEAD BLOCKER -> ' + CAST(bt.session_id AS VARCHAR(10))
        ELSE
            REPLICATE('   ', bt.lvl) +
            '|-- ' + CAST(bt.session_id AS VARCHAR(10))
    END AS BlockingTree,

    bt.display_path,

    r.session_id,
    r.blocking_session_id,

    s.login_name,
    s.host_name,
    s.program_name,

    DB_NAME(r.database_id) AS database_name,

    r.status,
    r.command,

    r.wait_type,
    r.wait_time / 1000 AS wait_seconds,
    r.wait_resource,

    r.cpu_time,
    r.total_elapsed_time / 1000 AS elapsed_seconds,

    r.reads,
    r.logical_reads,
    r.writes,

    at.transaction_begin_time,

    DATEDIFF
    (
        MINUTE,
        at.transaction_begin_time,
        GETDATE()
    ) AS transaction_age_minutes,

    -----------------------------------------------------------------------
    -- Running Statement
    -----------------------------------------------------------------------
    SUBSTRING
    (
        txt.text,
        (r.statement_start_offset / 2) + 1,
        (
            (
                CASE r.statement_end_offset
                    WHEN -1 THEN DATALENGTH(txt.text)
                    ELSE r.statement_end_offset
                END
                - r.statement_start_offset
            ) / 2
        ) + 1
    ) AS running_statement,

    txt.text AS batch_text,

    -----------------------------------------------------------------------
    -- Execution Plan
    -----------------------------------------------------------------------
    qp.query_plan AS xml_execution_plan,

    -----------------------------------------------------------------------
    -- Basic Recommendation
    -----------------------------------------------------------------------
    CASE

        WHEN r.wait_type LIKE 'LCK%'
            THEN 'Blocking - Review transaction duration and indexing'

        WHEN r.logical_reads > 100000
            THEN 'High Logical Reads - Possible scan or missing index'

        WHEN r.cpu_time > 10000
            THEN 'High CPU - Review execution plan'

        WHEN r.wait_type IN ('PAGEIOLATCH_SH','PAGEIOLATCH_EX')
            THEN 'Storage/IO Bottleneck'

        WHEN r.wait_type IN ('CXPACKET','CXCONSUMER')
            THEN 'Check Parallelism'

        ELSE 'Review execution plan'
    END AS recommendation

FROM BlockingTree bt

LEFT JOIN sys.dm_exec_requests r
    ON bt.session_id = r.session_id

LEFT JOIN sys.dm_exec_sessions s
    ON bt.session_id = s.session_id

LEFT JOIN sys.dm_tran_session_transactions st
    ON s.session_id = st.session_id

LEFT JOIN sys.dm_tran_active_transactions at
    ON st.transaction_id = at.transaction_id

OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) txt

-- Comment this OUTER APPLY if you want maximum lightweight execution
OUTER APPLY sys.dm_exec_query_plan(r.plan_handle) qp

ORDER BY bt.sort_path
OPTION (MAXRECURSION 100)
