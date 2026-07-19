USE [DBADB]
GO
/****** Object:  StoredProcedure [dbo].[Applications]    Script Date: 27-08-2025 11:24:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER     PROCEDURE [dbo].[Applications]
AS
BEGIN
    SET NOCOUNT ON;

    --===============================
    -- 1. Declare Variables
    --===============================
    DECLARE @sSQL NVARCHAR(MAX);
    DECLARE @SourceTableName SYSNAME = '[DBLoanguard].[dbo].[Applications]';
    DECLARE @DestinationTableName SYSNAME = '[DBLoanguard].[dbo].[BKPApplications]';
    
	DECLARE @filter NVARCHAR(MAX) ='CreatedOn < DATEADD(MONTH, -6, CAST(GETDATE() AS DATE))'; 
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
[ApplicationId],[ApplicationNo],[ProductId],[ApplicationDate],[SourcingChannel],[BranchCode],
	 [ExistingCustCustId1],[ExistingCustAcNo1],[ExistingCustCustId2],[ExistingCustAcNo2],
	 [ExistingCustCustId3],[ExistingCustAcNo3],[PurposeOfLoan],[LoanAmount],[LoanTenure],[LoanEMI],
	 [NoOfAdvanceEMI],[Scheme],[FirstRefName],[FirstRefRelWithApplicant],[FirstRefResAddress],[FirstRefCity],
	 [FirstRefState],[FirstRefPinCode],[FirstRefMobileNo],[FirstRefLandlineNo],[SecRefName],[SecRefRelWithApplicant],
	 [SecRefResAddress],[SecRefCity],[SecRefState],[SecRefPinCode],[SecRefMobileNo],[SecRefLandlineNo],[RelWithOtherBank],
	 [RelWithFinBank],[NatureOfRelation],[Remarks],[AppStatus],[ExistingCustomer],[CardType],[UsagePreference],[NomineeDetails],
	 [ApplicantNameOnCreditCard],[StatementPreferredDeliveryMode],[StatementPreferredMailingAddress],
	 [AddonExistingAxisBankCust],[AddonNameOnCreditCard],[IPAddress],[TypeOfLoan],[LoanCategory],[HoldRemark],
	 [SampledRemark],[CreatedBy],[CreatedOn],[DSAName],[DSANo],[RuleEvalStatus],[ScreenedRemark],[ServiceStatus],
	 [FileAD],[CreateMode],[CreateStatus],[ClientId],[AppstatusReportSentbyemail],[ModifiedOn],[ReverseAPIStatus],
	 [FolderCreateStatus],[LgStateId],[LgDistrictId],[LgCityId],[LgBranchId],[LgRegionId],[Subtype],[PortfolioNo],
	 [VerificationCode],[RejectRemark],[CreateStatusOn],[AssignedTo],[AssignedOn],[AssignedStatus],[ReadyForSampling],
	 [DHoldRemark],[DHoldRmkDatetime],[DHoldRmkAddedBy],[BSAnalysisStatus],[ModifiedBy],[OverAllVerificationStatus],
	 [OverAllVerificationRemark],[OverAllVerificationDatetime],[AppReopenRemarks],[ApplicationNoHashed],[ApplicationNoSalt],
	 [DisplayAppStatus],[AppSubStatusRmkId],[AppSubStatusRmk],[IsFaceMatchingDone],[IsInAutoDataEntry],[IsInAutoSampling],
	 [CallBackPostServiceStatus],[CallBackPostAttemptedOn],[DAssignedTo],[DAssignedOn],
	 [DAssignedStatus],[DLocked],[DLockedOn],[DAllocationType],[ScoreStatus],[ScoreReportStatus]
    FROM ' + @SourceTableName + N' WITH (READPAST, ROWLOCK)
    WHERE ' + @filter + N'
    ORDER BY ' + @column + N'
)
DELETE FROM CTE_ToDelete
OUTPUT 
 	   Deleted.[ApplicationId]
      ,Deleted.[ApplicationNo]
      ,Deleted.[ProductId]
      ,Deleted.[ApplicationDate]
      ,Deleted.[SourcingChannel]
      ,Deleted.[BranchCode]
      ,Deleted.[ExistingCustCustId1]
      ,Deleted.[ExistingCustAcNo1]
      ,Deleted.[ExistingCustCustId2]
      ,Deleted.[ExistingCustAcNo2]
      ,Deleted.[ExistingCustCustId3]
      ,Deleted.[ExistingCustAcNo3]
      ,Deleted.[PurposeOfLoan]
      ,Deleted.[LoanAmount]
      ,Deleted.[LoanTenure]
      ,Deleted.[LoanEMI]
      ,Deleted.[NoOfAdvanceEMI]
      ,Deleted.[Scheme]
      ,Deleted.[FirstRefName]
      ,Deleted.[FirstRefRelWithApplicant]
      ,Deleted.[FirstRefResAddress]
      ,Deleted.[FirstRefCity]
      ,Deleted.[FirstRefState]
      ,Deleted.[FirstRefPinCode]
      ,Deleted.[FirstRefMobileNo]
      ,Deleted.[FirstRefLandlineNo]
      ,Deleted.[SecRefName]
      ,Deleted.[SecRefRelWithApplicant]
      ,Deleted.[SecRefResAddress]
      ,Deleted.[SecRefCity]
      ,Deleted.[SecRefState]
      ,Deleted.[SecRefPinCode]
      ,Deleted.[SecRefMobileNo]
      ,Deleted.[SecRefLandlineNo]
      ,Deleted.[RelWithOtherBank]
      ,Deleted.[RelWithFinBank]
      ,Deleted.[NatureOfRelation]
      ,Deleted.[Remarks]
      ,Deleted.[AppStatus]
      ,Deleted.[ExistingCustomer]
      ,Deleted.[CardType]
      ,Deleted.[UsagePreference]
      ,Deleted.[NomineeDetails]
      ,Deleted.[ApplicantNameOnCreditCard]
      ,Deleted.[StatementPreferredDeliveryMode]
      ,Deleted.[StatementPreferredMailingAddress]
      ,Deleted.[AddonExistingAxisBankCust]
      ,Deleted.[AddonNameOnCreditCard]
      ,Deleted.[IPAddress]
      ,Deleted.[TypeOfLoan]
      ,Deleted.[LoanCategory]
      ,Deleted.[HoldRemark]
      ,Deleted.[SampledRemark]
      ,Deleted.[CreatedBy]
      ,Deleted.[CreatedOn]
      ,Deleted.[DSAName]
      ,Deleted.[DSANo]
      ,Deleted.[RuleEvalStatus]
      ,Deleted.[ScreenedRemark]
      ,Deleted.[ServiceStatus]
      ,Deleted.[FileAD]
      ,Deleted.[CreateMode]
      ,Deleted.[CreateStatus]
      ,Deleted.[ClientId]
      ,Deleted.[AppstatusReportSentbyemail]
      ,Deleted.[ModifiedOn]
      ,Deleted.[ReverseAPIStatus]
      ,Deleted.[FolderCreateStatus]
      ,Deleted.[LgStateId]
      ,Deleted.[LgDistrictId]
      ,Deleted.[LgCityId]
      ,Deleted.[LgBranchId]
      ,Deleted.[LgRegionId]
      ,Deleted.[Subtype]
      ,Deleted.[PortfolioNo]
      ,Deleted.[VerificationCode]
      ,Deleted.[RejectRemark]
      ,Deleted.[CreateStatusOn]
      ,Deleted.[AssignedTo]
      ,Deleted.[AssignedOn]
      ,Deleted.[AssignedStatus]
      ,Deleted.[ReadyForSampling]
      ,Deleted.[DHoldRemark]
      ,Deleted.[DHoldRmkDatetime]
      ,Deleted.[DHoldRmkAddedBy]
      ,Deleted.[BSAnalysisStatus]
      ,Deleted.[ModifiedBy]
      ,Deleted.[OverAllVerificationStatus]
      ,Deleted.[OverAllVerificationRemark]
      ,Deleted.[OverAllVerificationDatetime]
      ,Deleted.[AppReopenRemarks]
      ,Deleted.[ApplicationNoHashed]
      ,Deleted.[ApplicationNoSalt]
      ,Deleted.[DisplayAppStatus]
      ,Deleted.[AppSubStatusRmkId]
      ,Deleted.[AppSubStatusRmk]
      ,Deleted.[IsFaceMatchingDone]
      ,Deleted.[IsInAutoDataEntry]
      ,Deleted.[IsInAutoSampling]
      ,Deleted.[CallBackPostServiceStatus]
      ,Deleted.[CallBackPostAttemptedOn]
      ,Deleted.[DAssignedTo]
      ,Deleted.[DAssignedOn]
      ,Deleted.[DAssignedStatus]
      ,Deleted.[DLocked]
      ,Deleted.[DLockedOn]
      ,Deleted.[DAllocationType]
      ,Deleted.[ScoreStatus]
      ,Deleted.[ScoreReportStatus]
INTO ' + @DestinationTableName + N'(
     [ApplicationId],[ApplicationNo],[ProductId],[ApplicationDate],[SourcingChannel],[BranchCode],
	 [ExistingCustCustId1],[ExistingCustAcNo1],[ExistingCustCustId2],[ExistingCustAcNo2],
	 [ExistingCustCustId3],[ExistingCustAcNo3],[PurposeOfLoan],[LoanAmount],[LoanTenure],[LoanEMI],
	 [NoOfAdvanceEMI],[Scheme],[FirstRefName],[FirstRefRelWithApplicant],[FirstRefResAddress],[FirstRefCity],
	 [FirstRefState],[FirstRefPinCode],[FirstRefMobileNo],[FirstRefLandlineNo],[SecRefName],[SecRefRelWithApplicant],
	 [SecRefResAddress],[SecRefCity],[SecRefState],[SecRefPinCode],[SecRefMobileNo],[SecRefLandlineNo],[RelWithOtherBank],
	 [RelWithFinBank],[NatureOfRelation],[Remarks],[AppStatus],[ExistingCustomer],[CardType],[UsagePreference],[NomineeDetails],
	 [ApplicantNameOnCreditCard],[StatementPreferredDeliveryMode],[StatementPreferredMailingAddress],
	 [AddonExistingAxisBankCust],[AddonNameOnCreditCard],[IPAddress],[TypeOfLoan],[LoanCategory],[HoldRemark],
	 [SampledRemark],[CreatedBy],[CreatedOn],[DSAName],[DSANo],[RuleEvalStatus],[ScreenedRemark],[ServiceStatus],
	 [FileAD],[CreateMode],[CreateStatus],[ClientId],[AppstatusReportSentbyemail],[ModifiedOn],[ReverseAPIStatus],
	 [FolderCreateStatus],[LgStateId],[LgDistrictId],[LgCityId],[LgBranchId],[LgRegionId],[Subtype],[PortfolioNo],
	 [VerificationCode],[RejectRemark],[CreateStatusOn],[AssignedTo],[AssignedOn],[AssignedStatus],[ReadyForSampling],
	 [DHoldRemark],[DHoldRmkDatetime],[DHoldRmkAddedBy],[BSAnalysisStatus],[ModifiedBy],[OverAllVerificationStatus],
	 [OverAllVerificationRemark],[OverAllVerificationDatetime],[AppReopenRemarks],[ApplicationNoHashed],[ApplicationNoSalt],
	 [DisplayAppStatus],[AppSubStatusRmkId],[AppSubStatusRmk],[IsFaceMatchingDone],[IsInAutoDataEntry],[IsInAutoSampling],
	 [CallBackPostServiceStatus],[CallBackPostAttemptedOn],[DAssignedTo],[DAssignedOn],
	 [DAssignedStatus],[DLocked],[DLockedOn],[DAllocationType],[ScoreStatus],[ScoreReportStatus]
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
