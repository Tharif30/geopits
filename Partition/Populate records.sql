/* ============================================================
   SQL SERVER LAB DATA GENERATOR
   ============================================================

   Creates:

       dbo.[transaction]
           - Parent transaction table
           - 1,000,000 rows

       dbo.transaction_details
           - Child/detail table
           - 1,000,000 rows

   Relationships:

       transaction_details.trans_id
             -> transaction.trans_id

   Primary Key:

       transaction_details.transaction_detail_id

   Indexes:

       PK_transaction
       PK_transaction_details
       IX_transaction_cust_id
       IX_transaction_details_trans_id
       IX_transaction_details_transaction_date
       IX_transaction_details_product_id
       IX_transaction_details_region_date
       IX_transaction_date_status

   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @TargetRows BIGINT = 1000000;
DECLARE @BatchSize  INT = 50000;

DECLARE @RowsInserted BIGINT = 0;


/* ============================================================
   1. DROP EXISTING TABLES
   ============================================================ */

IF OBJECT_ID('dbo.transaction_details', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.transaction_details;
END;

IF OBJECT_ID('dbo.[transaction]', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.[transaction];
END;


/* ============================================================
   2. CREATE PARENT TRANSACTION TABLE
   ============================================================ */

CREATE TABLE dbo.[transaction]
(
    trans_id BIGINT IDENTITY(1,1) NOT NULL,

    cust_id INT NOT NULL,

    transaction_date DATE NOT NULL,

    transaction_amount DECIMAL(12,2) NOT NULL,

    transaction_status VARCHAR(20) NOT NULL,

    payment_method VARCHAR(20) NOT NULL,

    created_at DATETIME2(3) NOT NULL
        CONSTRAINT DF_transaction_created_at
        DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_transaction
        PRIMARY KEY CLUSTERED (trans_id)
);


/* ============================================================
   3. CREATE TRANSACTION DETAILS TABLE
   ============================================================ */

CREATE TABLE dbo.transaction_details
(
    transaction_detail_id BIGINT IDENTITY(1,1) NOT NULL,

    cust_id INT NOT NULL,

    trans_id BIGINT NOT NULL,

    transaction_date DATE NOT NULL,

    product_id INT NOT NULL,

    quantity SMALLINT NOT NULL,

    unit_price DECIMAL(10,2) NOT NULL,

    total_amount AS
    (
        CONVERT
        (
            DECIMAL(12,2),
            quantity * unit_price
        )
    ) PERSISTED,

    region VARCHAR(30) NULL,

    created_at DATETIME2(3) NOT NULL
        CONSTRAINT DF_transaction_details_created_at
        DEFAULT SYSUTCDATETIME(),


    /* Primary Key */

    CONSTRAINT PK_transaction_details
        PRIMARY KEY CLUSTERED
        (
            transaction_detail_id
        ),


    /* Foreign Key */

    CONSTRAINT FK_transaction_details_transaction
        FOREIGN KEY (trans_id)
        REFERENCES dbo.[transaction](trans_id)
);


/* ============================================================
   4. INSERT DATA IN BATCHES
   ============================================================ */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @TargetRows BIGINT = 1000000;
DECLARE @BatchSize  INT = 50000;

DECLARE @RowsInserted BIGINT = 0;


WHILE @RowsInserted < @TargetRows
BEGIN

    DECLARE @ThisBatch INT;

    SET @ThisBatch =
        CONVERT
        (
            INT,
            CASE
                WHEN @TargetRows - @RowsInserted > @BatchSize
                    THEN @BatchSize
                ELSE @TargetRows - @RowsInserted
            END
        );


    /* ========================================================
       Generate numbers for this batch
       ======================================================== */

    ;WITH E1(N) AS
    (
        SELECT 1
        FROM
        (
            VALUES
                (1),(1),(1),(1),(1),
                (1),(1),(1),(1),(1)
        ) X(N)
    ),

    E2(N) AS
    (
        SELECT 1
        FROM E1 A
        CROSS JOIN E1 B
    ),

    E4(N) AS
    (
        SELECT 1
        FROM E2 A
        CROSS JOIN E2 B
    ),

    Numbers AS
    (
        SELECT TOP (@ThisBatch)

            ROW_NUMBER() OVER
            (
                ORDER BY (SELECT NULL)
            ) AS N

        FROM E4
    )


    /* ========================================================
       Insert into parent transaction table
       ======================================================== */

    INSERT INTO dbo.[transaction]
    (
        cust_id,
        transaction_date,
        transaction_amount,
        transaction_status,
        payment_method
    )
    SELECT

        CONVERT
        (
            INT,
            @RowsInserted + N
        ),

        DATEADD
        (
            DAY,

            -ABS
            (
                CHECKSUM(NEWID())
            ) % 1825,

            CAST(GETDATE() AS DATE)
        ),

        CAST
        (
            (
                ABS
                (
                    CHECKSUM(NEWID())
                ) % 100000
            ) / 100.0
            AS DECIMAL(12,2)
        ),

        CASE
            WHEN ABS(CHECKSUM(NEWID())) % 4 = 0
                THEN 'SUCCESS'

            WHEN ABS(CHECKSUM(NEWID())) % 4 = 1
                THEN 'SUCCESS'

            WHEN ABS(CHECKSUM(NEWID())) % 4 = 2
                THEN 'PENDING'

            ELSE 'FAILED'
        END,

        CASE
            WHEN ABS(CHECKSUM(NEWID())) % 4 = 0
                THEN 'CARD'

            WHEN ABS(CHECKSUM(NEWID())) % 4 = 1
                THEN 'UPI'

            WHEN ABS(CHECKSUM(NEWID())) % 4 = 2
                THEN 'NETBANKING'

            ELSE 'WALLET'
        END

    FROM Numbers;


    /* ========================================================
       Insert corresponding detail rows
       ======================================================== */

    INSERT INTO dbo.transaction_details
    (
        cust_id,
        trans_id,
        transaction_date,
        product_id,
        quantity,
        unit_price,
        region
    )
    SELECT

        t.cust_id,

        t.trans_id,

        t.transaction_date,

        ABS
        (
            CHECKSUM(NEWID())
        ) % 10000 + 1,

        ABS
        (
            CHECKSUM(NEWID())
        ) % 10 + 1,

        CAST
        (
            (
                ABS
                (
                    CHECKSUM(NEWID())
                ) % 500000
            ) / 100.0
            AS DECIMAL(10,2)
        ),

        CASE
            WHEN ABS(CHECKSUM(NEWID())) % 6 = 0
                THEN 'NORTH'

            WHEN ABS(CHECKSUM(NEWID())) % 6 = 1
                THEN 'SOUTH'

            WHEN ABS(CHECKSUM(NEWID())) % 6 = 2
                THEN 'EAST'

            WHEN ABS(CHECKSUM(NEWID())) % 6 = 3
                THEN 'WEST'

            WHEN ABS(CHECKSUM(NEWID())) % 6 = 4
                THEN 'CENTRAL'

            ELSE 'NORTHEAST'
        END

    FROM dbo.[transaction] t

    WHERE t.cust_id > @RowsInserted
      AND t.cust_id <= @RowsInserted + @ThisBatch;


    /* ========================================================
       Update progress
       ======================================================== */

    SET @RowsInserted =
        @RowsInserted + @ThisBatch;


    PRINT
        CONCAT
        (
            'Rows inserted: ',
            @RowsInserted,
            ' / ',
            @TargetRows
        );

END;


/* ============================================================
   5. CREATE NONCLUSTERED INDEXES
   ============================================================ */


/* ------------------------------------------------------------
   Transaction table
   ------------------------------------------------------------ */

CREATE NONCLUSTERED INDEX IX_transaction_cust_id
ON dbo.[transaction]
(
    cust_id
);


CREATE NONCLUSTERED INDEX IX_transaction_date_status
ON dbo.[transaction]
(
    transaction_date,
    transaction_status
)
INCLUDE
(
    cust_id,
    transaction_amount
);


/* ------------------------------------------------------------
   Transaction details table
   ------------------------------------------------------------ */

CREATE NONCLUSTERED INDEX IX_transaction_details_cust_id
ON dbo.transaction_details
(
    cust_id
);


CREATE NONCLUSTERED INDEX IX_transaction_details_trans_id
ON dbo.transaction_details
(
    trans_id
);


CREATE NONCLUSTERED INDEX IX_transaction_details_transaction_date
ON dbo.transaction_details
(
    transaction_date
);


CREATE NONCLUSTERED INDEX IX_transaction_details_product_id
ON dbo.transaction_details
(
    product_id
);


CREATE NONCLUSTERED INDEX IX_transaction_details_region_date
ON dbo.transaction_details
(
    region,
    transaction_date
);


/* ============================================================
   6. UPDATE STATISTICS
   ============================================================ */

UPDATE STATISTICS dbo.[transaction]
WITH FULLSCAN;

UPDATE STATISTICS dbo.transaction_details
WITH FULLSCAN;


/* ============================================================
   7. VALIDATE ROW COUNTS
   ============================================================ */

SELECT
    'dbo.[transaction]' AS table_name,
    COUNT_BIG(*) AS row_count
FROM dbo.[transaction]

UNION ALL

SELECT
    'dbo.transaction_details' AS table_name,
    COUNT_BIG(*) AS row_count
FROM dbo.transaction_details;


/* ============================================================
   8. VALIDATE FOREIGN KEY RELATIONSHIP
   ============================================================ */

SELECT
    COUNT_BIG(*) AS orphan_detail_rows
FROM dbo.transaction_details d
LEFT JOIN dbo.[transaction] t
    ON d.trans_id = t.trans_id
WHERE t.trans_id IS NULL;


/* ============================================================
   9. SHOW INDEXES
   ============================================================ */

SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS schema_name,
    OBJECT_NAME(i.object_id) AS table_name,
    i.index_id,
    i.name AS index_name,
    i.type_desc
FROM sys.indexes i
WHERE i.object_id IN
(
    OBJECT_ID('dbo.[transaction]'),
    OBJECT_ID('dbo.transaction_details')
)
ORDER BY
    table_name,
    index_id;
