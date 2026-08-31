USE [DBADB]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Create or alter   PROCEDURE [dbo].[ApplicantMaster]
AS
BEGIN
    SET NOCOUNT ON;

    --===============================
    -- 1. Declare Variables
    --===============================
    DECLARE @sSQL NVARCHAR(MAX);
    DECLARE @SourceTableName SYSNAME = '[DBLoanguard].[dbo].[ApplicantMaster]';
    DECLARE @DestinationTableName SYSNAME = '[DBLoanguard].[dbo].[BKPApplicantMaster]';
    
	DECLARE @filter NVARCHAR(MAX) ='EXISTS ( SELECT 1 FROM [DBLoanguard].[dbo].[Applications] A
    WHERE A.ApplicationId = [DBLoanguard].[dbo].[ApplicantMaster].[ApplicationId]
      AND A.CreatedOn < DATEADD(MONTH, -6, CAST(GETDATE() AS DATE))';
	DECLARE @column NVARCHAR(MAX) ='ApplicationId';
	
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
[ApplicantId],[ApplicationNo],[LoanguardId],[TypeId],[ApplicantTitle],[ApplicantType],[ApplicantName],
[ApplicantFirstName],[ApplicantMiddleName],[ApplicantLastName],[ApplicantFathHusName],[ApplicantDateOfBirth],[ApplicantGender],
[ApplicantStatus],[ApplicantNoOfDependents],[ApplicantReligion],[ApplicantPanNo],[ApplicantEducation],[APresentAddress],[APresentAddressCity],
[APresentAddressState],[APresentAddressPinCode],[APresentAddressCountry],[APermanentAddress],[APermanentAddressCity],[APermanentAddressState],
[APermanentAddressPinCode],[APermanentAddressCountry],[ApplicantTelephoneNo],[ApplicantMobileNo],[ApplicantEmailId],[ApplicantAadharNo],
[ApplicantVoterIdNo],[ApplicantOccupation],[ApplicantCompanyName],[ApplicantTypeOfComapny],[ApplicantDesignation],
[ApplicantExpInCurrentCompany],[ApplicantTotalExperiance],[ACompanyAddress],[ACompanyAddressCity],[ACompanyAddressState],
[ACompanyAddressPinCode],[ACompanyAddressCountry],[ACompanyTelephoneNo],[ACompanyOfficialMailId],[ApplicantMonthlySalary],[ApplicantAnnualSalary],
[ApplicantNetProfit],[ApplicantOtherIncRs],[ApplicantOtherIncSrc],[ApplicantBankAcNo],[ApplicantBankName],[ApplicantBankBrName],[ApplicantCustomerId],
[ApplicantAcType],[OpenedIn],[ApplicantCreditCardNo],[ApplicantCrCardIssBank],[PassportNo],[ApplicantMothersMaidenName],[ApplicantNationality],
[CompanyDepartment],[EmployeeId],[NoOfEmplyees],[ApplicantGrossTurnover],[PassportDateOfIssue],[PassportDateOfExpiry],[PassportPlaceOfIssue],
[ApplicantDrivingLicenseNo],[VehicleType],[VehicleOwnedType],[APresentAddressLandmark],[APresentAddressStdCode],[APresentAddressLandLine],[MobileType],
[DurationAtCurrentAddress],[CurrentResidanceStatus],[ACompanyAddressLandmark],[ACompanyAddressStdCode],[ACompanyAddressMobileNo],[ACompanyAddressExtension],
[ACompanyAddressFaxNo],[APermanentAddressLandmark],[APermanentAddressStdCode],[APermanentAddressLandline],[APermanentAddressMobileNo],[AddonApplicantTitle],
[AddonApplicantFirstName],[AddonApplicantMiddleName],[AddonApplicantLastName],[AddonApplicantDateOfBirth],[AddonApplicantMothersMaidenName],[AddonApplicantGender],
[AddonApplicantNationality],[AddonConfirmation],[AddonRalationshipwitApplicant],[AddonApplicantContactNo],[AddonApplicantEmailId],[AddonAccountNo],[CurrentPermtAddSame],
[IPAddress],[AppCommLanguage],[ApplicantRationCardNo],[AppNonIndNameOfEntity],[AppNonIndRegNo],[AppNonIndDateOfIncorparation],[AppNonIndPanNo],[AppNonIndCommLanguage],
[AppNonIndRegOfficeAddress],[AppNonIndLandmarks],[AppNonIndCity],[AppNonIndPincode],[AppNonIndState],[AppNonIndTelephone],[AppNonIndMobileNo],
[AppNonIndContactPerson],[AppNonIndEmail],[AppNonIndWebsite],[ApplicationId],[FolderCreateStatus],[AM_CreatedOn],[AM_CreatedBy]
    FROM ' + @SourceTableName + N' WITH (READPAST, ROWLOCK)
    WHERE ' + @filter + N'
    
)ORDER BY ' + @column + N'
)
DELETE FROM CTE_ToDelete
OUTPUT 
 	  	   Deleted.[ApplicantId]
      ,Deleted.[ApplicationNo]
      ,Deleted.[LoanguardId]
      ,Deleted.[TypeId]
      ,Deleted.[ApplicantTitle]
      ,Deleted.[ApplicantType]
      ,Deleted.[ApplicantName]
      ,Deleted.[ApplicantFirstName]
      ,Deleted.[ApplicantMiddleName]
      ,Deleted.[ApplicantLastName]
      ,Deleted.[ApplicantFathHusName]
      ,Deleted.[ApplicantDateOfBirth]
      ,Deleted.[ApplicantGender]
      ,Deleted.[ApplicantStatus]
      ,Deleted.[ApplicantNoOfDependents]
      ,Deleted.[ApplicantReligion]
      ,Deleted.[ApplicantPanNo]
      ,Deleted.[ApplicantEducation]
      ,Deleted.[APresentAddress]
      ,Deleted.[APresentAddressCity]
      ,Deleted.[APresentAddressState]
      ,Deleted.[APresentAddressPinCode]
      ,Deleted.[APresentAddressCountry]
      ,Deleted.[APermanentAddress]
      ,Deleted.[APermanentAddressCity]
      ,Deleted.[APermanentAddressState]
      ,Deleted.[APermanentAddressPinCode]
      ,Deleted.[APermanentAddressCountry]
      ,Deleted.[ApplicantTelephoneNo]
      ,Deleted.[ApplicantMobileNo]
      ,Deleted.[ApplicantEmailId]
      ,Deleted.[ApplicantAadharNo]
      ,Deleted.[ApplicantVoterIdNo]
      ,Deleted.[ApplicantOccupation]
      ,Deleted.[ApplicantCompanyName]
      ,Deleted.[ApplicantTypeOfComapny]
      ,Deleted.[ApplicantDesignation]
      ,Deleted.[ApplicantExpInCurrentCompany]
      ,Deleted.[ApplicantTotalExperiance]
      ,Deleted.[ACompanyAddress]
      ,Deleted.[ACompanyAddressCity]
      ,Deleted.[ACompanyAddressState]
      ,Deleted.[ACompanyAddressPinCode]
      ,Deleted.[ACompanyAddressCountry]
      ,Deleted.[ACompanyTelephoneNo]
      ,Deleted.[ACompanyOfficialMailId]
      ,Deleted.[ApplicantMonthlySalary]
      ,Deleted.[ApplicantAnnualSalary]
      ,Deleted.[ApplicantNetProfit]
      ,Deleted.[ApplicantOtherIncRs]
      ,Deleted.[ApplicantOtherIncSrc]
      ,Deleted.[ApplicantBankAcNo]
      ,Deleted.[ApplicantBankName]
      ,Deleted.[ApplicantBankBrName]
      ,Deleted.[ApplicantCustomerId]
      ,Deleted.[ApplicantAcType]
      ,Deleted.[OpenedIn]
      ,Deleted.[ApplicantCreditCardNo]
      ,Deleted.[ApplicantCrCardIssBank]
      ,Deleted.[PassportNo]
      ,Deleted.[ApplicantMothersMaidenName]
      ,Deleted.[ApplicantNationality]
      ,Deleted.[CompanyDepartment]
      ,Deleted.[EmployeeId]
      ,Deleted.[NoOfEmplyees]
      ,Deleted.[ApplicantGrossTurnover]
      ,Deleted.[PassportDateOfIssue]
      ,Deleted.[PassportDateOfExpiry]
      ,Deleted.[PassportPlaceOfIssue]
      ,Deleted.[ApplicantDrivingLicenseNo]
      ,Deleted.[VehicleType]
      ,Deleted.[VehicleOwnedType]
      ,Deleted.[APresentAddressLandmark]
      ,Deleted.[APresentAddressStdCode]
      ,Deleted.[APresentAddressLandLine]
      ,Deleted.[MobileType]
      ,Deleted.[DurationAtCurrentAddress]
      ,Deleted.[CurrentResidanceStatus]
      ,Deleted.[ACompanyAddressLandmark]
      ,Deleted.[ACompanyAddressStdCode]
      ,Deleted.[ACompanyAddressMobileNo]
      ,Deleted.[ACompanyAddressExtension]
      ,Deleted.[ACompanyAddressFaxNo]
      ,Deleted.[APermanentAddressLandmark]
      ,Deleted.[APermanentAddressStdCode]
      ,Deleted.[APermanentAddressLandline]
      ,Deleted.[APermanentAddressMobileNo]
      ,Deleted.[AddonApplicantTitle]
      ,Deleted.[AddonApplicantFirstName]
      ,Deleted.[AddonApplicantMiddleName]
      ,Deleted.[AddonApplicantLastName]
      ,Deleted.[AddonApplicantDateOfBirth]
      ,Deleted.[AddonApplicantMothersMaidenName]
      ,Deleted.[AddonApplicantGender]
      ,Deleted.[AddonApplicantNationality]
      ,Deleted.[AddonConfirmation]
      ,Deleted.[AddonRalationshipwitApplicant]
      ,Deleted.[AddonApplicantContactNo]
      ,Deleted.[AddonApplicantEmailId]
      ,Deleted.[AddonAccountNo]
      ,Deleted.[CurrentPermtAddSame]
      ,Deleted.[IPAddress]
      ,Deleted.[AppCommLanguage]
      ,Deleted.[ApplicantRationCardNo]
      ,Deleted.[AppNonIndNameOfEntity]
      ,Deleted.[AppNonIndRegNo]
      ,Deleted.[AppNonIndDateOfIncorparation]
      ,Deleted.[AppNonIndPanNo]
      ,Deleted.[AppNonIndCommLanguage]
      ,Deleted.[AppNonIndRegOfficeAddress]
      ,Deleted.[AppNonIndLandmarks]
      ,Deleted.[AppNonIndCity]
      ,Deleted.[AppNonIndPincode]
      ,Deleted.[AppNonIndState]
      ,Deleted.[AppNonIndTelephone]
      ,Deleted.[AppNonIndMobileNo]
      ,Deleted.[AppNonIndContactPerson]
      ,Deleted.[AppNonIndEmail]
      ,Deleted.[AppNonIndWebsite]
      ,Deleted.[ApplicationId]
      ,Deleted.[FolderCreateStatus]
      ,Deleted.[AM_CreatedOn]
      ,Deleted.[AM_CreatedBy]
INTO ' + @DestinationTableName + N'(
[ApplicantId],[ApplicationNo],[LoanguardId],[TypeId],[ApplicantTitle],[ApplicantType],[ApplicantName],
[ApplicantFirstName],[ApplicantMiddleName],[ApplicantLastName],[ApplicantFathHusName],[ApplicantDateOfBirth],[ApplicantGender],
[ApplicantStatus],[ApplicantNoOfDependents],[ApplicantReligion],[ApplicantPanNo],[ApplicantEducation],[APresentAddress],[APresentAddressCity],
[APresentAddressState],[APresentAddressPinCode],[APresentAddressCountry],[APermanentAddress],[APermanentAddressCity],[APermanentAddressState],
[APermanentAddressPinCode],[APermanentAddressCountry],[ApplicantTelephoneNo],[ApplicantMobileNo],[ApplicantEmailId],[ApplicantAadharNo],
[ApplicantVoterIdNo],[ApplicantOccupation],[ApplicantCompanyName],[ApplicantTypeOfComapny],[ApplicantDesignation],
[ApplicantExpInCurrentCompany],[ApplicantTotalExperiance],[ACompanyAddress],[ACompanyAddressCity],[ACompanyAddressState],
[ACompanyAddressPinCode],[ACompanyAddressCountry],[ACompanyTelephoneNo],[ACompanyOfficialMailId],[ApplicantMonthlySalary],[ApplicantAnnualSalary],
[ApplicantNetProfit],[ApplicantOtherIncRs],[ApplicantOtherIncSrc],[ApplicantBankAcNo],[ApplicantBankName],[ApplicantBankBrName],[ApplicantCustomerId],
[ApplicantAcType],[OpenedIn],[ApplicantCreditCardNo],[ApplicantCrCardIssBank],[PassportNo],[ApplicantMothersMaidenName],[ApplicantNationality],
[CompanyDepartment],[EmployeeId],[NoOfEmplyees],[ApplicantGrossTurnover],[PassportDateOfIssue],[PassportDateOfExpiry],[PassportPlaceOfIssue],
[ApplicantDrivingLicenseNo],[VehicleType],[VehicleOwnedType],[APresentAddressLandmark],[APresentAddressStdCode],[APresentAddressLandLine],[MobileType],
[DurationAtCurrentAddress],[CurrentResidanceStatus],[ACompanyAddressLandmark],[ACompanyAddressStdCode],[ACompanyAddressMobileNo],[ACompanyAddressExtension],
[ACompanyAddressFaxNo],[APermanentAddressLandmark],[APermanentAddressStdCode],[APermanentAddressLandline],[APermanentAddressMobileNo],[AddonApplicantTitle],
[AddonApplicantFirstName],[AddonApplicantMiddleName],[AddonApplicantLastName],[AddonApplicantDateOfBirth],[AddonApplicantMothersMaidenName],[AddonApplicantGender],
[AddonApplicantNationality],[AddonConfirmation],[AddonRalationshipwitApplicant],[AddonApplicantContactNo],[AddonApplicantEmailId],[AddonAccountNo],[CurrentPermtAddSame],
[IPAddress],[AppCommLanguage],[ApplicantRationCardNo],[AppNonIndNameOfEntity],[AppNonIndRegNo],[AppNonIndDateOfIncorparation],[AppNonIndPanNo],[AppNonIndCommLanguage],
[AppNonIndRegOfficeAddress],[AppNonIndLandmarks],[AppNonIndCity],[AppNonIndPincode],[AppNonIndState],[AppNonIndTelephone],[AppNonIndMobileNo],
[AppNonIndContactPerson],[AppNonIndEmail],[AppNonIndWebsite],[ApplicationId],[FolderCreateStatus],[AM_CreatedOn],[AM_CreatedBy]
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
