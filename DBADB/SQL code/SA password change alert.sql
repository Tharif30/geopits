USE [DBADB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[PasswordHistory](
	[user_name] [varchar](10) NULL,
	[updatedate] [varchar](30) NULL
) ON [PRIMARY]
GO

--Job step code
Declare @old varchar(50)
Declare @new varchar(50)
Declare @body varchar(100)
Declare @sub varchar(50)
set @sub = 'Client name SA Password Changed On '+(select @@SERVERNAME)+''  --Change
SET @body = 'This alert to inform that SA Account Password has been Changed.'
select @new = convert(varchar,(LOGINPROPERTY ('sa', 'PasswordLastSetTime')),9)
select top 1 @old = updatedate from DBADB.dbo.PasswordHistory order by updatedate desc
if (@old<@new)
BEGIN
EXEC msdb.dbo.Sp_send_dbmail
@profile_name = '',
@recipients = '',
@copy_recipients ='',
@blind_copy_recipients='',
@subject = @sub,
@body = @body,
@body_format ='html';
insert into DBADB.dbo.PasswordHistory values ('sa', @new)
END
