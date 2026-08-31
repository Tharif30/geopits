USE vasdev_sel;
GO

DECLARE @BaseDate DATETIME = '2024-12-31 23:59:59';
DECLARE @i INT = 1;

DECLARE @Subs TABLE (subscription_id VARCHAR(50));

WHILE @i <= 1000
BEGIN
    DECLARE @SubId VARCHAR(50) = NEWID();

    INSERT INTO dbo.tbl_user_subscriptions (
        subscription_id,
        subscription_mobile,
        subscription_tel_id,
        subscription_plan_id,
        subscription_amount,
        subscription_region_id,
        subscription_status,
        subscription_is_subscribed,
        subscription_addedat,
        subscription_updatedat,
        subscription_churn_date
    )
    VALUES (
        @SubId,
        '91111111' + RIGHT('0' + CAST(@i AS VARCHAR), 2),
        'TELC' + CAST(@i AS VARCHAR),
        'PLANC' + CAST(@i AS VARCHAR),
        9.9900,
        'REGION1',
        'CHURNED',
        0,
        DATEADD(DAY, -40, @BaseDate),
        DATEADD(DAY, -35, @BaseDate),
        DATEADD(DAY, -30, @BaseDate)   -- < 2024-12-31
    );

    INSERT INTO @Subs VALUES (@SubId);


INSERT INTO dbo.tbl_user_lifecycle (
    usr_lifecycle_id,
    usr_lifecycle_mobile,
    usr_lifecycle_status,
    usr_lifecycle_user_subscription_id,
    usr_lifecycle_createddate,
    usr_lifecycle_updateddate
)
SELECT
    NEWID(),
    '91111111' + RIGHT('0' + CAST(ROW_NUMBER() OVER (ORDER BY subscription_id) AS VARCHAR), 2),
    'CHURNED',
    subscription_id,
    DATEADD(DAY, -25, @BaseDate),
    DATEADD(DAY, -25, @BaseDate)
FROM @Subs;

INSERT INTO dbo.tbl_ads2shistory (
    history_id,
    history_ad_partner_id,
    history_campaign_id,
    history_subscription_id,
    history_region_id,
    history_tel_id,
    history_plan_amount,
    history_type,
    history_createdat
)
SELECT
    NEWID(),
    'ADP_CHURN',
    'CMP_CHURN',
    subscription_id,
    'REGION1',
    'TEL_CHURN',
    9.9900,
    'CHURN',
    DATEADD(DAY, -20, @BaseDate)
FROM @Subs;


    INSERT INTO dbo.tbl_user_hits (
        hit_id,
        hit_user_agent,
        hit_remote_ip,
        hit_channel,
        hit_createddate
    )
    VALUES (
        NEWID(),
        'Mozilla/5.0',
        '10.10.10.' + CAST(@i AS VARCHAR),
        'WEB',
        DATEADD(DAY, -(@i + 10), @BaseDate)
    );




    SET @i += 1;

END;

