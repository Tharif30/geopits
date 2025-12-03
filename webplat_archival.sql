 
 
 SELECT 
          count(*)
    FROM [nimbelpayapidb].[dbo].[Logs_ClientCalls] WITH (ROWLOCK, READPAST)
    WHERE RequestDateTime <= (SELECT TOP 1 [CreatedOn] FROM [nimbelpayapidblogs].[dbo].[LogsFetchDate]);

 SELECT count(*)
    FROM [nimbelpayapidb].[dbo].[Logs_WebhookAPI] WITH (ROWLOCK, READPAST)
    WHERE RequestDateTime <= (SELECT MAX(CreatedOn) FROM [nimbelpayapidblogs].[dbo].[LogsFetchDate]);

	SELECT count(*)
    FROM [nimbelpayapidb].[dbo].[Logs_WebhookClients] WITH (ROWLOCK, READPAST)
    WHERE RequestDateTime <= (SELECT MAX(CreatedOn) FROM [nimbelpayapidblogs].[dbo].[LogsFetchDate]);

	SELECT count(*)
    FROM [nimbelpayapidb].[dbo].[Logs_ApiRep] WITH (ROWLOCK, READPAST)
    WHERE RequestDateTime <= (SELECT TOP 1 [CreatedOn] FROM [nimbelpayapidblogs].[dbo].[LogsFetchDate]);

	SELECT count(*)
    FROM [nimbelpayapidb].[dbo].[Logs_ActivityCalls] WITH (ROWLOCK, READPAST)
    WHERE CreatedOn <= (SELECT TOP 1 [CreatedOn] FROM [nimbelpayapidblogs].[dbo].[LogsFetchDate]);

SELECT TOP (1000) [DBID]
      ,[DBNAME]
      ,[TableName]
      ,[SchemaName]
      ,[rows]
      ,[TotalSpaceKB]
      ,[TotalSpaceMB]
      ,[UsedSpaceKB]
      ,[UsedSpaceMB]
      ,[UnusedSpaceKB]
      ,[UnusedSpaceMB]
      ,[Date]
  FROM [DBADB].[dbo].[TableSizeData]
  where tablename in ('Logs_ActivityCalls',	
					  'Logs_ApiRep'		  ,
					  'Logs_Application'  ,
					  'Logs_BlockUser'	  ,
					  'Logs_ClientCalls'  ,
					  'Logs_Cookies'	  ,
					  'Logs_DMTTransaction'	,
					  'Logs_EmailRep'	  ,
					  'Logs_LoginHistory' ,
					  'Logs_MobileNotifications',
					  'Logs_Notification' ,
					  'Logs_SMS'		  ,
					  'Logs_WebhookAPI'	  ,
					  'Logs_WebhookClients'	)
					  order by date desc



