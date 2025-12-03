USE [dbadb]
GO

-----------------------------------------------------------------------------
--Table for Login Audits
-----------------------------------------------------------------------------
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[WebVasLoginAudit](
	[AuditID] [int] IDENTITY(1,1) NOT NULL,
	[LoginName] [nvarchar](100) NULL,
	[IPAddress] [nvarchar](50) NULL,
	[LoginTime] [datetime] NULL,
	[AlertMessage] [nvarchar](4000) NULL,
PRIMARY KEY CLUSTERED 
(
	[AuditID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[WebVasLoginAudit] ADD  DEFAULT (getdate()) FOR [LoginTime]
GO


