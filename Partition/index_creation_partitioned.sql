--check index on partitioned table
SELECT
    i.name,
    i.type_desc,
    i.index_id
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('dbo.Transactions');

--create clustered index
CREATE CLUSTERED INDEX CX_Transactions
ON dbo.Transactions
(
    TransactionDate,
    TransactionID
)
ON ps_TransactionDate(TransactionDate);


--check the partitioned index
SELECT
    i.name,
    i.type_desc,
    i.data_space_id,
    ds.name AS DataSpace
FROM sys.indexes i
JOIN sys.data_spaces ds
    ON i.data_space_id = ds.data_space_id
WHERE i.object_id = OBJECT_ID('dbo.Transactions');

--index partitions
SELECT
    i.name AS IndexName,
    p.partition_number,
    p.rows
FROM sys.indexes i
JOIN sys.partitions p
    ON i.object_id = p.object_id
    AND i.index_id = p.index_id
WHERE i.object_id = OBJECT_ID('dbo.Transactions')
ORDER BY
    i.name,
    p.partition_number;