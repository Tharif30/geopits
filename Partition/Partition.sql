
--Step 0
USE master;
GO

IF DB_ID('PartitionDemo') IS NOT NULL
BEGIN
    ALTER DATABASE PartitionDemo SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE PartitionDemo;
END
GO

CREATE DATABASE PartitionDemo;
GO

USE PartitionDemo;
GO
---------------------------------------------------------
---------------------------------------------------------
--Step 1 Partition Function
CREATE PARTITION FUNCTION pf_TransactionDate (DATE)
AS RANGE RIGHT
FOR VALUES
(
    '2026-02-01',
    '2026-03-01',
    '2026-04-01',
    '2026-05-01'
);
GO

--Verify the function
SELECT
    pf.name AS PartitionFunction,
    pf.boundary_value_on_right,
    prv.boundary_id,
    prv.value AS BoundaryValue
FROM sys.partition_functions pf
LEFT JOIN sys.partition_range_values prv
    ON pf.function_id = prv.function_id
WHERE pf.name = 'pf_TransactionDate'
ORDER BY prv.boundary_id;

--no of partitions 
SELECT
    name,
    fanout AS NumberOfPartitions
FROM sys.partition_functions
WHERE name = 'pf_TransactionDate';
---------------------------------------------------------
---------------------------------------------------------
--Step 2 Partition Scheme
CREATE PARTITION SCHEME ps_TransactionDate
AS PARTITION pf_TransactionDate
ALL TO ([PRIMARY]);
GO
---------------------------------------------------------
---------------------------------------------------------
--Step 3 Create the partitioned table
CREATE TABLE dbo.Transactions
(
    TransactionID BIGINT NOT NULL,
    TransactionDate DATE NOT NULL,
    Amount DECIMAL(18,2) NOT NULL,
    CustomerID INT NOT NULL
)
ON ps_TransactionDate(TransactionDate);
GO

--verification
SELECT
    t.name AS TableName,
    i.name AS IndexName,
    p.partition_number,
    p.rows
FROM sys.tables t
JOIN sys.indexes i
    ON t.object_id = i.object_id
JOIN sys.partitions p
    ON i.object_id = p.object_id
    AND i.index_id = p.index_id
WHERE t.name = 'Transactions'
ORDER BY p.partition_number;

--insert 
INSERT INTO dbo.Transactions
(
    TransactionID,
    TransactionDate,
    Amount,
    CustomerID
)
VALUES
(1, '2026-01-15', 100.00, 101),
(2, '2026-01-20', 200.00, 102),

(3, '2026-02-10', 300.00, 103),
(4, '2026-02-20', 400.00, 104),

(5, '2026-03-10', 500.00, 105),
(6, '2026-03-20', 600.00, 106),

(7, '2026-04-10', 700.00, 107),
(8, '2026-04-20', 800.00, 108),

(9, '2026-05-10', 900.00, 109);
GO
---------------------------------------------------------
---------------------------------------------------------
SELECT
    TransactionID,
    TransactionDate,
    Amount,
    $PARTITION.pf_TransactionDate(TransactionDate) AS PartitionNumber
FROM dbo.Transactions
ORDER BY TransactionDate;


SELECT *
FROM dbo.Transactions
ORDER BY TransactionDate;

