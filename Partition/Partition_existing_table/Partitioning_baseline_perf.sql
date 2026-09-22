--Test 1
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
EXEC dbo.usp_TransactionPerformanceTest
    @StartDate = '2025-01-01',
    @EndDate   = '2025-12-31';
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;



CHECKPOINT;
DBCC DROPCLEANBUFFERS;

--Test 2
    SET STATISTICS IO ON;
SET STATISTICS TIME ON;
EXEC dbo.usp_TransactionPerformanceTest
    @StartDate = '2026-01-01',
    @EndDate   = '2026-01-31';
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

CHECKPOINT;
DBCC DROPCLEANBUFFERS;

--Test 3
   SET STATISTICS IO ON;
SET STATISTICS TIME ON;
EXEC dbo.usp_TransactionPerformanceTest
    @StartDate = '2020-01-01',
    @EndDate   = '2026-08-31';
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;


SELECT
    ps.name AS partition_scheme,
    pf.name AS partition_function,
    pf.boundary_value_on_right,
    ds.destination_id,
    fg.name AS filegroup_name
FROM sys.partition_schemes ps
JOIN sys.partition_functions pf
    ON ps.function_id = pf.function_id
JOIN sys.destination_data_spaces ds
    ON ps.data_space_id = ds.partition_scheme_id
JOIN sys.filegroups fg
    ON ds.data_space_id = fg.data_space_id
ORDER BY
    ps.name,
    ds.destination_id;


    SELECT
    t.name AS table_name,
    i.name AS index_name,
    i.type_desc,
    ds.name AS data_space_name
FROM sys.tables t
JOIN sys.indexes i
    ON t.object_id = i.object_id
JOIN sys.data_spaces ds
    ON i.data_space_id = ds.data_space_id
WHERE t.name IN
(
    'transaction',
    'transaction_details'
)
ORDER BY
    t.name,
    i.index_id;



    SELECT
    'transaction' AS table_name,
    $PARTITION.PF_TransactionYear(transaction_date) AS partition_number,
    COUNT_BIG(*) AS row_count,
    MIN(transaction_date) AS min_date,
    MAX(transaction_date) AS max_date
FROM dbo.[transaction]
GROUP BY
    $PARTITION.PF_TransactionYear(transaction_date)

UNION ALL

SELECT
    'transaction_details',
    $PARTITION.PF_TransactionYear(transaction_date),
    COUNT_BIG(*),
    MIN(transaction_date),
    MAX(transaction_date)
FROM dbo.transaction_details
GROUP BY
    $PARTITION.PF_TransactionYear(transaction_date)

ORDER BY
    table_name,
    partition_number;


