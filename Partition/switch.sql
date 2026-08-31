SELECT *
FROM dbo.Transactions
ORDER BY TransactionDate;


CREATE TABLE dbo.Transactions_Archive
(
    TransactionID BIGINT NOT NULL,
    TransactionDate DATE NOT NULL,
    Amount DECIMAL(18,2) NOT NULL,
    CustomerID INT NOT NULL
);
GO

ALTER TABLE dbo.Transactions_Archive
ADD CONSTRAINT CK_Transactions_Archive_P1
CHECK
(
    TransactionDate < '2026-02-01'
);
GO

ALTER TABLE dbo.Transactions
SWITCH PARTITION 1
TO dbo.Transactions_Archive;
GO

SELECT *
FROM dbo.Transactions_Archive
ORDER BY TransactionDate;

SELECT *
FROM dbo.Transactions
ORDER BY TransactionDate;
    