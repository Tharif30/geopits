USE [DBADB]
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


Create     PROCEDURE [dbo].[BankStatementTransactionDetailsValidate]
AS
BEGIN
    SET NOCOUNT ON;

    --===============================
    -- 1. Declare Variables
    --===============================
    DECLARE @sSQL NVARCHAR(MAX);
    DECLARE @SourceTableName SYSNAME = ' [DBLoanguard].[dbo].[BankStatementTransactionDetailsValidate]';
    DECLARE @DestinationTableName SYSNAME = '[DBLoanguard].[dbo].[BKPBankStatementTransactionDetailsValidate]';
    
	DECLARE @filter NVARCHAR(MAX) ='CreatedOn < DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))'; 
	DECLARE @column NVARCHAR(MAX) ='CreatedOn';
	
    DECLARE @ExecutionId UNIQUEIDENTIFIER = NEWID(); -- Unique run ID
    DECLARE @filter_log NVARCHAR(MAX) = @filter + ' | RunId=' + CAST(@ExecutionId AS NVARCHAR(36));

    DECLARE @ID INT;                     -- New IID_NEW for this run
    DECLARE @rCount BIGINT;              
    DECLARE @TotalrCount BIGINT = 0;
    DECLARE @BatchSize INT = 1000;
    DECLARE @MaxBatchSize INT = 100000;
    DECLARE @starttime DATETIME;
    DECLARE @endtime DATETIME;

    --===============================
    -- 2. Insert New Master Row
    --===============================
    INSERT INTO TBL_RETENTION_MASTER (SourceTableName, DestinationTableName, Filter, LastUpdated)
    VALUES (@SourceTableName, @DestinationTableName, @filter_log, GETDATE());

    -- Capture new row ID for this execution
    SET @ID = SCOPE_IDENTITY();
    PRINT 'Processing IID_NEW: ' + CAST(@ID AS VARCHAR);

    --===============================
    -- 3. Archival Loop
    --===============================
    UPDATE_BATCH:
    SET @starttime = GETDATE();

    BEGIN TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- Build dynamic SQL for batch archival using CTE with READPAST

	SET @sSQL = 
N'SET IDENTITY_INSERT ' + @DestinationTableName + N' ON;

;WITH CTE_ToDelete AS (
    SELECT TOP (' + CAST(@BatchSize AS NVARCHAR(10)) + N') 
[SrNo],[BankStatementValidateID],[TransactionDate],[TransactionNarration],[TransactionTypeDrAmount],
[TransactionTypeCrAmount],[TransactionTypeDrCrAmount],[TransactionTypeDrCr],[BalanceAmount],[CreatedBy],
[CreatedOn],[ModifiedBy],[ModifiedOn],[DeletedBy],[DeletedOn],[Deleted],[ChequeNo],
[PageNo],[IPAddress],[ModifiedDate],[BankStatementID],[FontSize],[FontFamily],
[Narration_Lable]
    FROM ' + @SourceTableName + N' WITH (READPAST, ROWLOCK)
    WHERE ' + @filter + N'
    ORDER BY ' + @column + N'
)
DELETE FROM CTE_ToDelete
OUTPUT 
	   Deleted.[SrNo]
      ,Deleted.[BankStatementValidateID]
      ,Deleted.[TransactionDate]
      ,Deleted.[TransactionNarration]
      ,Deleted.[TransactionTypeDrAmount]
      ,Deleted.[TransactionTypeCrAmount]
      ,Deleted.[TransactionTypeDrCrAmount]
      ,Deleted.[TransactionTypeDrCr]
      ,Deleted.[BalanceAmount]
      ,Deleted.[CreatedBy]
      ,Deleted.[CreatedOn]
      ,Deleted.[ModifiedBy]
      ,Deleted.[ModifiedOn]
      ,Deleted.[DeletedBy]
      ,Deleted.[DeletedOn]
      ,Deleted.[Deleted]
      ,Deleted.[ChequeNo]
      ,Deleted.[PageNo]
      ,Deleted.[IPAddress]
      ,Deleted.[ModifiedDate]
      ,Deleted.[BankStatementID]
      ,Deleted.[FontSize]
      ,Deleted.[FontFamily]
      ,Deleted.[Narration_Lable]  
INTO ' + @DestinationTableName + N'(
[SrNo],[BankStatementValidateID],[TransactionDate],[TransactionNarration],[TransactionTypeDrAmount],
[TransactionTypeCrAmount],[TransactionTypeDrCrAmount],[TransactionTypeDrCr],[BalanceAmount],[CreatedBy],
[CreatedOn],[ModifiedBy],[ModifiedOn],[DeletedBy],[DeletedOn],[Deleted],[ChequeNo],
[PageNo],[IPAddress],[ModifiedDate],[BankStatementID],[FontSize],[FontFamily],
[Narration_Lable]
    );

SET IDENTITY_INSERT ' + @DestinationTableName + N' OFF;';


    PRINT @sSQL;
    EXEC sys.sp_executesql @sSQL;

    -- Get number of rows moved in this batch
    SET @rCount = @@ROWCOUNT;
    PRINT 'Batch Rows Moved: ' + CAST(ISNULL(@rCount, 0) AS VARCHAR(30));

    COMMIT;  -- Commit fast to release locks

    --===============================
    -- 4. Logging
    --===============================
    IF @rCount > 0
    BEGIN
        SET @TotalrCount = @TotalrCount + @rCount;

        -- Log batch archival
        INSERT INTO tbl_Retention_Logs (SourceTableName, DestinationTableName, TotalDataTransfered, Comment, EntryDate)
        VALUES (@SourceTableName, @DestinationTableName, @rCount, 'Successfully - Archived', GETDATE());

        -- Update the master table row for this execution (after commit to avoid blocking SELECT)
        UPDATE TBL_RETENTION_MASTER
        SET LastUpdated = GETDATE(), [Rows] = ISNULL(@TotalrCount, 0)
        WHERE IID_NEW = @ID;
    END
    ELSE
    BEGIN
        -- Log no records found
        INSERT INTO tbl_Retention_Logs (SourceTableName, DestinationTableName, TotalDataTransfered, Comment, EntryDate)
        VALUES (@SourceTableName, @DestinationTableName, 0, 'No Records Found or Already Archived', GETDATE());
    END

    --===============================
    -- 5. Adjust Batch Size Dynamically
    --===============================
    SET @endtime = GETDATE();
    PRINT 'Execution Time: ' + CAST(DATEDIFF(SECOND, @starttime, @endtime) AS VARCHAR(3)) + ' Sec';

    IF DATEDIFF(SECOND, @starttime, @endtime) < 5
    BEGIN
        IF (@BatchSize < @MaxBatchSize)
            SET @BatchSize = @BatchSize + 1000;
    END
    ELSE IF (DATEDIFF(SECOND, @starttime, @endtime) > 5)
    BEGIN
        SET @BatchSize = @BatchSize - 1000;
        IF (@BatchSize < 1000)
            SET @BatchSize = 1000;
    END

    -- Wait to avoid overwhelming live transactions
    WAITFOR DELAY '00:00:10';

    -- Continue if rows still exist
    IF @rCount > 0 GOTO UPDATE_BATCH;

    --===============================
    -- 6. Final Update for This Execution
    --===============================
    UPDATE TBL_RETENTION_MASTER
    SET LastUpdated = GETDATE(),
        [Rows] = ISNULL(@TotalrCount, 0)
    WHERE IID_NEW = @ID;

    PRINT 'Archival Completed Successfully. Total Rows Archived: ' + CAST(@TotalrCount AS VARCHAR(30));
END;
GO


