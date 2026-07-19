USE DBADB;
GO

CREATE TABLE dbo.TempDBGrowthHistory
(
    CaptureTime DATETIME NOT NULL DEFAULT GETDATE(),
    TempDBSizeGB DECIMAL(18,2)
);
GO

--select * from dbo.TempDBGrowthHistory


--truncate table dbo.TempDBGrowthHistory