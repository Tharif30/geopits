/* ============================================================================
   PartitionDemo — In-place year-wise partitioning
   Tables      : dbo.[transaction], dbo.transaction_details
   Method      : In-place rebuild of clustered PK onto a partition scheme
                 (NO shadow/staging table is created)
   Partition   : Yearly, on transaction_date
   Filegroups  : One new filegroup per year + one "future" catch-all
   ----------------------------------------------------------------------------
   READ BEFORE RUNNING
   1. FULL BACKUP the database first. This script drops and rebuilds both
      clustered PKs (i.e. rewrites both tables) plus every nonclustered index.
   2. This causes table-level locking while indexes rebuild, unless your
      edition/version supports ONLINE = ON (Enterprise, or Standard 2019+
      with restrictions). Run in a maintenance window on Standard/older builds.
   3. Rebuilding needs roughly as much extra space as the data being moved,
      temporarily, in the NEW filegroups.
   4. Adjust @DataPath below if your data files live somewhere else.
   5. This assumes transaction_date is always identical between a
      transaction row and its transaction_details rows for the same trans_id
      (needed because the FK becomes composite). Verify this before running:
         SELECT COUNT(*) FROM dbo.transaction_details td
         JOIN dbo.[transaction] t ON t.trans_id = td.trans_id
         WHERE t.transaction_date <> td.transaction_date;
      -- should return 0
============================================================================ */

USE PartitionDemo;
GO

------------------------------------------------------------------------------
-- STEP 0: Find current default data file path 
------------------------------------------------------------------------------
DECLARE @DataPath NVARCHAR(260);

SELECT @DataPath = LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1)
select * FROM sys.master_files
WHERE database_id = DB_ID('PartitionDemo') AND type_desc = 'ROWS' AND file_id = 1;

PRINT 'Data path detected: ' + @DataPath;
-- If this looks wrong, hardcode it manually below instead of using @DataPath.

------------------------------------------------------------------------------
-- STEP 1: Create filegroups (one per year + one future catch-all)
------------------------------------------------------------------------------
ALTER DATABASE PartitionDemo ADD FILEGROUP FG_2021;
ALTER DATABASE PartitionDemo ADD FILEGROUP FG_2022;
ALTER DATABASE PartitionDemo ADD FILEGROUP FG_2023;
ALTER DATABASE PartitionDemo ADD FILEGROUP FG_2024;
ALTER DATABASE PartitionDemo ADD FILEGROUP FG_2025;
ALTER DATABASE PartitionDemo ADD FILEGROUP FG_2026;
ALTER DATABASE PartitionDemo ADD FILEGROUP FG_FUTURE;  -- catch-all for 2027+
GO

------------------------------------------------------------------------------
-- STEP 2: Add one data file per filegroup
-- Sizes are set modestly given current volumes (~85 MB + ~292 MB total data);
-- resize/adjust FILEGROWTH for your real growth pattern.
------------------------------------------------------------------------------
DECLARE @DataPath NVARCHAR(260)='C:\Users\Public\PartitionDemo\';
--SELECT @DataPath = LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1)
--FROM sys.master_files
--WHERE database_id = DB_ID('PartitionDemo') AND type_desc = 'ROWS' AND file_id = 1;
--print (@DataPath)

EXEC('ALTER DATABASE PartitionDemo ADD FILE
      (NAME = N''PD_2021'', FILENAME = N''' + @DataPath + 'PD_2021.ndf'', SIZE = 50MB, FILEGROWTH = 25MB)
      TO FILEGROUP FG_2021;');

EXEC('ALTER DATABASE PartitionDemo ADD FILE
      (NAME = N''PD_2022'', FILENAME = N''' + @DataPath + 'PD_2022.ndf'', SIZE = 100MB, FILEGROWTH = 50MB)
      TO FILEGROUP FG_2022;');

EXEC('ALTER DATABASE PartitionDemo ADD FILE
      (NAME = N''PD_2023'', FILENAME = N''' + @DataPath + 'PD_2023.ndf'', SIZE = 100MB, FILEGROWTH = 50MB)
      TO FILEGROUP FG_2023;');

EXEC('ALTER DATABASE PartitionDemo ADD FILE
      (NAME = N''PD_2024'', FILENAME = N''' + @DataPath + 'PD_2024.ndf'', SIZE = 100MB, FILEGROWTH = 50MB)
      TO FILEGROUP FG_2024;');

EXEC('ALTER DATABASE PartitionDemo ADD FILE
      (NAME = N''PD_2025'', FILENAME = N''' + @DataPath + 'PD_2025.ndf'', SIZE = 100MB, FILEGROWTH = 50MB)
      TO FILEGROUP FG_2025;');

EXEC('ALTER DATABASE PartitionDemo ADD FILE
      (NAME = N''PD_2026'', FILENAME = N''' + @DataPath + 'PD_2026.ndf'', SIZE = 100MB, FILEGROWTH = 50MB)
      TO FILEGROUP FG_2026;');

EXEC('ALTER DATABASE PartitionDemo ADD FILE
      (NAME = N''PD_FUTURE'', FILENAME = N''' + @DataPath + 'PD_FUTURE.ndf'', SIZE = 50MB, FILEGROWTH = 50MB)
      TO FILEGROUP FG_FUTURE;');
GO

------------------------------------------------------------------------------
-- STEP 3: Partition function
-- RANGE RIGHT: boundary value belongs to the partition on its right,
-- so '2022-01-01' starts the 2022 partition.
--
-- Boundaries -> Partitions:
--   P1: < 2022-01-01                -> 2021 data (partial year, from 2021-08-30)
--   P2: 2022-01-01 to < 2023-01-01  -> 2022
--   P3: 2023-01-01 to < 2024-01-01  -> 2023
--   P4: 2024-01-01 to < 2025-01-01  -> 2024
--   P5: 2025-01-01 to < 2026-01-01  -> 2025
--   P6: 2026-01-01 to < 2027-01-01  -> 2026 (partial year, through 2026-08-28)
--   P7: >= 2027-01-01               -> future catch-all
------------------------------------------------------------------------------
CREATE PARTITION FUNCTION PF_TransactionYear (DATE)
AS RANGE RIGHT FOR VALUES
('2022-01-01', '2023-01-01', '2024-01-01', '2025-01-01', '2026-01-01', '2027-01-01');
GO

------------------------------------------------------------------------------
-- STEP 4: Partition scheme — maps each partition to its filegroup
-- One scheme shared by both tables so their yearly partitions line up
------------------------------------------------------------------------------
CREATE PARTITION SCHEME PS_TransactionYear
AS PARTITION PF_TransactionYear
TO (FG_2021, FG_2022, FG_2023, FG_2024, FG_2025, FG_2026, FG_FUTURE);
GO

------------------------------------------------------------------------------
-- STEP 5: Drop the FK 
------------------------------------------------------------------------------
ALTER TABLE dbo.transaction_details
DROP CONSTRAINT FK_transaction_details_transaction;
GO

------------------------------------------------------------------------------
-- STEP 6: Rebuild PK_transaction as a composite, partition-aligned PK
-- This IS the "in-place" data movement step for the parent table —
-- SQL Server physically rewrites the table onto the new filegroups.
------------------------------------------------------------------------------
ALTER TABLE dbo.[transaction]
DROP CONSTRAINT PK_transaction;
GO

ALTER TABLE dbo.[transaction]
ADD CONSTRAINT PK_transaction PRIMARY KEY CLUSTERED (trans_id, transaction_date)
ON PS_TransactionYear(transaction_date);
-- Enterprise / Standard 2019+: append WITH (ONLINE = ON) to reduce blocking
GO

------------------------------------------------------------------------------
-- STEP 7: Rebuild PK_transaction_details the same way
------------------------------------------------------------------------------
ALTER TABLE dbo.transaction_details
DROP CONSTRAINT PK_transaction_details;
GO

ALTER TABLE dbo.transaction_details
ADD CONSTRAINT PK_transaction_details PRIMARY KEY CLUSTERED (transaction_detail_id, transaction_date)
ON PS_TransactionYear(transaction_date);
-- Enterprise / Standard 2019+: append WITH (ONLINE = ON) to reduce blocking
GO

------------------------------------------------------------------------------
-- STEP 8: Recreate the FK as composite, matching the new parent key
------------------------------------------------------------------------------
ALTER TABLE dbo.transaction_details
ADD CONSTRAINT FK_transaction_details_transaction
FOREIGN KEY (trans_id, transaction_date)
REFERENCES dbo.[transaction] (trans_id, transaction_date);
GO

------------------------------------------------------------------------------
-- STEP 9: Rebuild nonclustered indexes, aligned to the same scheme
-- All are non-unique, so none need transaction_date added to their key --
-- SQL Server routes each row to the matching partition automatically.
------------------------------------------------------------------------------

-- dbo.[transaction]
CREATE NONCLUSTERED INDEX IX_transaction_cust_id
ON dbo.[transaction] (cust_id)
WITH (DROP_EXISTING = ON)
ON PS_TransactionYear(transaction_date);

CREATE NONCLUSTERED INDEX IX_transaction_date_status
ON dbo.[transaction] (transaction_date, transaction_status)
INCLUDE (cust_id, transaction_amount)
WITH (DROP_EXISTING = ON)
ON PS_TransactionYear(transaction_date);

-- dbo.transaction_details
CREATE NONCLUSTERED INDEX IX_transaction_details_cust_id
ON dbo.transaction_details (cust_id)
WITH (DROP_EXISTING = ON)
ON PS_TransactionYear(transaction_date);

CREATE NONCLUSTERED INDEX IX_transaction_details_product_id
ON dbo.transaction_details (product_id)
WITH (DROP_EXISTING = ON)
ON PS_TransactionYear(transaction_date);

CREATE NONCLUSTERED INDEX IX_transaction_details_region_date
ON dbo.transaction_details (region, transaction_date)
WITH (DROP_EXISTING = ON)
ON PS_TransactionYear(transaction_date);

CREATE NONCLUSTERED INDEX IX_transaction_details_trans_id
ON dbo.transaction_details (trans_id)
WITH (DROP_EXISTING = ON)
ON PS_TransactionYear(transaction_date);

CREATE NONCLUSTERED INDEX IX_transaction_details_transaction_date
ON dbo.transaction_details (transaction_date)
WITH (DROP_EXISTING = ON)
ON PS_TransactionYear(transaction_date);
GO

------------------------------------------------------------------------------
-- STEP 10: Update statistics after the rewrite
------------------------------------------------------------------------------
UPDATE STATISTICS dbo.[transaction] WITH FULLSCAN;
UPDATE STATISTICS dbo.transaction_details WITH FULLSCAN;
GO

------------------------------------------------------------------------------
-- STEP 11: Verification
------------------------------------------------------------------------------

-- 11a. Confirm both tables are on the partition scheme
SELECT t.name AS table_name, i.name AS index_name, i.type_desc,
       ds.name AS partition_scheme_or_filegroup, ds.type_desc AS storage_type
FROM sys.indexes i
JOIN sys.tables t ON t.object_id = i.object_id
JOIN sys.data_spaces ds ON ds.data_space_id = i.data_space_id
WHERE t.name IN ('transaction', 'transaction_details')
ORDER BY t.name, i.index_id;

-- 11b. Row counts per partition, per table -- compare against the
--      year-wise counts you already have (41006 / 119948 / 119838 / ... )
SELECT OBJECT_NAME(p.object_id) AS table_name,
       p.partition_number,
       prv.value AS boundary_value,
       p.rows
FROM sys.partitions p
LEFT JOIN sys.partition_schemes ps ON ps.name = 'PS_TransactionYear'
LEFT JOIN sys.partition_functions pf ON pf.function_id = ps.function_id
LEFT JOIN sys.partition_range_values prv
       ON prv.function_id = pf.function_id AND prv.boundary_id = p.partition_number
WHERE p.object_id IN (OBJECT_ID('dbo.[transaction]'), OBJECT_ID('dbo.transaction_details'))
  AND p.index_id IN (0, 1)   -- heap or clustered index
ORDER BY table_name, p.partition_number;

-- 11c. Confirm every index on both tables is aligned to PS_TransactionYear
--      (an empty result set here = fully aligned, which is what we want)
SELECT t.name AS table_name, i.name AS index_name
FROM sys.indexes i
JOIN sys.tables t ON t.object_id = i.object_id
JOIN sys.data_spaces ds ON ds.data_space_id = i.data_space_id
WHERE t.name IN ('transaction', 'transaction_details')
  AND ds.type_desc <> 'PARTITION_SCHEME';
GO

--12
SELECT
*,
    $PARTITION.PF_TransactionYear(transaction_date) as partition_no             
FROM dbo.[Transaction]
ORDER BY Transaction_Date;