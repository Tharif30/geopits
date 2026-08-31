SELECT 'RuleServiceLog' AS TableName, COUNT(*) AS RecordCount
FROM [DBLoanguard].[dbo].[RuleServiceLog]
WHERE [Date] < DATEADD(DAY, -10, CAST(GETDATE() AS date))

UNION ALL

SELECT 'AutoDataEntryServiceLog', COUNT(*)
FROM [DBLoanguard].[dbo].[AutoDataEntryServiceLog]
WHERE [LogDate] < DATEADD(DAY, -10, CAST(GETDATE() AS date))

UNION ALL

SELECT 'AutoSamplingServiceLog', COUNT(*)
FROM [DBLoanguard].[dbo].[AutoSamplingServiceLog]
WHERE [LogDate] < DATEADD(DAY, -10, CAST(GETDATE() AS date))

UNION ALL

SELECT 'OCRServiceLog', COUNT(*)
FROM [DBLoanguard].[dbo].[OCRServiceLog]
WHERE [LogDate] < DATEADD(DAY, -10, CAST(GETDATE() AS date))

UNION ALL

SELECT 'WebAPIRequestLog', COUNT(*)
FROM [DBLoanguard].[dbo].[WebAPIRequestLog]
WHERE [Date] < DATEADD(DAY, -10, CAST(GETDATE() AS date))

UNION ALL

SELECT 'ReverseAPIResponseLog', COUNT(*)
FROM [DBLoanguard].[dbo].[ReverseAPIResponseLog]
WHERE [CreatedOn] < DATEADD(DAY, -10, CAST(GETDATE() AS date))

UNION ALL

SELECT 'LGLog', COUNT(*)
FROM [DBLoanguard].[dbo].[LGLog]
WHERE [LogDate] < DATEADD(DAY, -10, CAST(GETDATE() AS date))

UNION ALL

SELECT 'MerchantURLLogDetails', COUNT(*)
FROM [DBLoanguard].[dbo].[MerchantURLLogDetails]
WHERE [ResponseOn] < DATEADD(DAY, -10, CAST(GETDATE() AS date))

UNION ALL

SELECT 'CallBackPostServiceLog', COUNT(*)
FROM [DBLoanguard].[dbo].[CallBackPostServiceLog]
WHERE [LogDate] < DATEADD(DAY, -10, CAST(GETDATE() AS date));


-----------------------------------------------------------------------------------------------------
--===================================================================================================
--===================================================================================================
-----------------------------------------------------------------------------------------------------
SELECT 'TimeAnalysis' AS TableName, COUNT(*) AS RecordCount
FROM [DBLoanguard].[dbo].[TimeAnalysis]
WHERE [ActivityTime] < CAST(GETDATE() AS DATE)

UNION ALL

SELECT 'AppAllocationHistory', COUNT(*)
FROM [DBLoanguard].[dbo].[AppAllocationHistory]
WHERE [CreatedOn] < CAST(GETDATE() AS DATE)

UNION ALL

SELECT 'DocumentRuleMessages', COUNT(*)
FROM [DBLoanguard].[dbo].[DocumentRuleMessages]
WHERE CreatedOn >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0)
  AND CreatedOn <  DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)

UNION ALL

SELECT 'BankStatementTransactionDetails', COUNT(*)
FROM [DBLoanguard].[dbo].[BankStatementTransactionDetails]
WHERE [CreatedOn] < DATEADD(MONTH, -3, CAST(GETDATE() AS DATE));


-----------------------------------------------------------------------------------------------------
--===================================================================================================
--===================================================================================================
-----------------------------------------------------------------------------------------------------
SELECT 'BankStatementTransactionDetails' AS TableName, COUNT(*) AS RecordCount
FROM [DBLoanguard].[dbo].[BankStatementTransactionDetails]
WHERE [CreatedOn] < DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))

UNION ALL

SELECT 'MerchantResponseDetails', COUNT(*)
FROM [DBLoanguard].[dbo].[MerchantResponseDetails]
WHERE [ResponseOn] < DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))

UNION ALL

SELECT 'BankStatement', COUNT(*)
FROM [DBLoanguard].[dbo].[BankStatement]
WHERE [CreatedOn] < DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))

UNION ALL

SELECT 'BankStatementValidate', COUNT(*)
FROM [DBLoanguard].[dbo].[BankStatementValidate]
WHERE [CreatedOn] < DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))

UNION ALL

SELECT 'ITRTransactionDetails', COUNT(*)
FROM [DBLoanguard].[dbo].[ITRTransactionDetails]
WHERE [CreatedOn] < DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))

UNION ALL

SELECT 'ITR', COUNT(*)
FROM [DBLoanguard].[dbo].[ITR]
WHERE [CreatedOn] < DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))

UNION ALL

SELECT 'ITRValidateTransactionDetails', COUNT(*)
FROM [DBLoanguard].[dbo].[ITRValidateTransactionDetails]
WHERE [CreatedOn] < DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))

UNION ALL

SELECT 'ITRValidate', COUNT(*)
FROM [DBLoanguard].[dbo].[ITRValidate]
WHERE [CreatedOn] < DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))

UNION ALL

SELECT 'Form16TransactionDetails', COUNT(*)
FROM [DBLoanguard].[dbo].[Form16TransactionDetails]
WHERE [CreatedOn] < DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))

UNION ALL

SELECT 'Form16', COUNT(*)
FROM [DBLoanguard].[dbo].[Form16]
WHERE [CreatedOn] < DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))

UNION ALL

SELECT 'Form16ValidateTransactionDetails', COUNT(*)
FROM [DBLoanguard].[dbo].[Form16ValidateTransactionDetails]
WHERE [CreatedOn] < DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))

UNION ALL

SELECT 'Form16Validate', COUNT(*)
FROM [DBLoanguard].[dbo].[Form16Validate]
WHERE [CreatedOn] < DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))

UNION ALL

SELECT 'BankStatementTransactionDetailsValidate', COUNT(*)
FROM [DBLoanguard].[dbo].[BankStatementTransactionDetailsValidate]
WHERE [CreatedOn] < DATEADD(MONTH, -3, CAST(GETDATE() AS DATE));


-----------------------------------------------------------------------------------------------------
--===================================================================================================
--===================================================================================================
-----------------------------------------------------------------------------------------------------

-- Applications older than 6 months
SELECT 'Applications' AS TableName, COUNT(*) AS RecordCount
FROM [DBLoanguard].[dbo].[Applications]
WHERE [CreatedOn] < DATEADD(MONTH, -6, CAST(GETDATE() AS DATE))

UNION ALL

-- ApplicationCustomData linked to old Applications
SELECT 'ApplicationCustomData', COUNT(*)
FROM [DBLoanguard].[dbo].[ApplicationCustomData] AC
WHERE EXISTS (
    SELECT 1
    FROM [DBLoanguard].[dbo].[Applications] A
    WHERE A.ApplicationId = AC.ApplicationId
      AND A.CreatedOn < DATEADD(MONTH, -6, CAST(GETDATE() AS DATE))
)

UNION ALL

-- ApplicantMaster linked to old Applications
SELECT 'ApplicantMaster', COUNT(*)
FROM [DBLoanguard].[dbo].[ApplicantMaster] AM
WHERE EXISTS (
    SELECT 1
    FROM [DBLoanguard].[dbo].[Applications] A
    WHERE A.ApplicationId = AM.ApplicationId
      AND A.CreatedOn < DATEADD(MONTH, -6, CAST(GETDATE() AS DATE))
)

UNION ALL

-- DocumentValidatingMessages linked to old Applications
SELECT 'DocumentValidatingMessages', COUNT(*)
FROM [DBLoanguard].[dbo].[DocumentValidatingMessages] DVM
WHERE EXISTS (
    SELECT 1
    FROM [DBLoanguard].[dbo].[Applications] A
    WHERE A.ApplicationId = DVM.ApplicationId
      AND A.CreatedOn < DATEADD(MONTH, -6, CAST(GETDATE() AS DATE))
)

UNION ALL

-- DocumentManualTrigger linked to old Applications
SELECT 'DocumentManualTrigger', COUNT(*)
FROM [DBLoanguard].[dbo].[DocumentManualTrigger] DMT
WHERE EXISTS (
    SELECT 1
    FROM [DBLoanguard].[dbo].[Applications] A
    WHERE A.ApplicationId = DMT.ApplicationId
      AND A.CreatedOn < DATEADD(MONTH, -6, CAST(GETDATE() AS DATE))
)

UNION ALL

-- DeletedDocumentDetails older than 6 months
SELECT 'DeletedDocumentDetails', COUNT(*)
FROM [DBLoanguard].[dbo].[DeletedDocumentDetails]
WHERE [DeletedOn] <= DATEADD(MONTH, -6, CAST(GETDATE() AS DATE));
-----------------------------------------------------------------------------------------------------
--===================================================================================================
--===================================================================================================
-----------------------------------------------------------------------------------------------------