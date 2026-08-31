USE vasdev_sel;
GO

DECLARE @BaseDate DATETIME = '2024-12-31 23:59:59';
DECLARE @i INT;

SET @i = 1;
--
--dbo.tbl_user_hits
--
WHILE @i <= 50
BEGIN
    INSERT INTO dbo.tbl_user_hits (
        hit_id,
        hit_user_agent,
        hit_remote_ip,
        hit_referer,
        hit_mobile_number,
        hit_tel_id,
        hit_plan_id,
        hit_region_id,
        hit_channel,
        hit_data_flow,
        hit_mode,
        hit_ad_partner_id,
        hit_campaignid,
        hit_click_id,
        hit_service_id,
        hit_createddate,
        hit_updateddate,
        hit_email
    )
    VALUES (
        NEWID(),
        'Mozilla/5.0',
        '192.168.1.' + CAST(@i AS VARCHAR),
        'https://google.com',
        '90000000' + RIGHT('0' + CAST(@i AS VARCHAR), 2),
        'TEL' + CAST(@i AS VARCHAR),
        'PLAN' + CAST(@i AS VARCHAR),
        'REGION1',
        'WEB',
        'SUBSCRIBE',
        'LIVE',
        'ADP1',
        'CMP' + CAST(@i AS VARCHAR),
        'CLICK' + CAST(@i AS VARCHAR),
        'SRV1',
        DATEADD(DAY, -@i, @BaseDate),
        DATEADD(DAY, -@i, @BaseDate),
        'user' + CAST(@i AS VARCHAR) + '@test.com'
    );

    SET @i += 1;
END;

--
--dbo.tbl_ads2shistory
--

WHILE @i <= 50
BEGIN
    INSERT INTO dbo.tbl_ads2shistory (
        history_id,
        history_ad_partner_id,
        history_campaign_id,
        history_subscription_id,
        history_region_id,
        history_tel_id,
        history_plan_amount,
        history_click_id,
        history_type,
        history_campaign_cost_type,
        history_ad_partner_cost,
        history_createdat,
        history_updatedat
    )
    VALUES (
        NEWID(),
        'ADP1',
        'CMP' + CAST(@i AS VARCHAR),
        'SUB' + CAST(@i AS VARCHAR),
        'REGION1',
        'TEL' + CAST(@i AS VARCHAR),
        10.5000,
        'CLICK' + CAST(@i AS VARCHAR),
        'CHARGE',
        'CPC',
        2.5000,
        DATEADD(DAY, -@i, @BaseDate),
        DATEADD(DAY, -@i, @BaseDate)
    );

    SET @i += 1;
END;



--dbo.tbl_user_lifecycle
--
WHILE @i <= 50
BEGIN
    INSERT INTO dbo.tbl_user_lifecycle (
        usr_lifecycle_id,
        usr_lifecycle_mobile,
        usr_lifecycle_session_id,
        usr_lifecycle_status,
        usr_lifecycle_tel_id,
        usr_lifecycle_plan_id,
        usr_lifecycle_region_id,
        usr_lifecycle_channel,
        usr_lifecycle_data_flow,
        usr_lifecycle_subscription_mode,
        usr_lifecycle_ad_partner_id,
        usr_lifecycle_campaignid,
        usr_lifecycle_click_id,
        usr_lifecycle_service_id,
        usr_lifecycle_createddate,
        usr_lifecycle_updateddate,
        usr_lifecycle_charge_amount,
        usr_lifecycle_is_callback,
        usr_lifecycle_is_fallback
    )
    VALUES (
        NEWID(),
        '90000000' + RIGHT('0' + CAST(@i AS VARCHAR), 2),
        'SESSION' + CAST(@i AS VARCHAR),
        'ACTIVE',
        'TEL' + CAST(@i AS VARCHAR),
        'PLAN' + CAST(@i AS VARCHAR),
        'REGION1',
        'WEB',
        'SUBSCRIBE',
        'LIVE',
        'ADP1',
        'CMP' + CAST(@i AS VARCHAR),
        'CLICK' + CAST(@i AS VARCHAR),
        'SRV1',
        DATEADD(DAY, -@i, @BaseDate),
        DATEADD(DAY, -@i, @BaseDate),
        9.9900,
        0,
        0
    );

    SET @i += 1;
END;
--

--
--dbo.tbl_user_subscriptions
--
WHILE @i <= 50
BEGIN
    INSERT INTO dbo.tbl_user_subscriptions (
        subscription_id,
        subscription_mobile,
        subscription_tel_id,
        subscription_plan_id,
        subscription_plan_validity,
        subscription_amount,
        subscription_region_id,
        subscription_currency,
        subscription_service_id,
        subscription_data_flow,
        subscription_mode,
        subscription_campaignid,
        subscription_ad_partner_id,
        subscription_channel,
        subscription_click_id,
        subscription_status,
        subscription_is_subscribed,
        subscription_addedat,
        subscription_updatedat,
        subscription_start_at,
        subscription_end_at,
        subscription_last_renewal_date,
        subscription_ist_start_at,
        subscription_ist_end_at
    )
    VALUES (
        NEWID(),
        '90000000' + RIGHT('0' + CAST(@i AS VARCHAR), 2),
        'TEL' + CAST(@i AS VARCHAR),
        'PLAN' + CAST(@i AS VARCHAR),
        30,
        9.9900,
        'REGION1',
        'INR',
        'SRV1',
        'SUBSCRIBE',
        'LIVE',
        'CMP' + CAST(@i AS VARCHAR),
        'ADP1',
        'WEB',
        'CLICK' + CAST(@i AS VARCHAR),
        'ACTIVE',
        1,
        DATEADD(DAY, -@i, @BaseDate),
        DATEADD(DAY, -@i, @BaseDate),
        DATEDIFF(SECOND, '1970-01-01', DATEADD(DAY, -@i, @BaseDate)),
        DATEDIFF(SECOND, '1970-01-01', DATEADD(DAY, -@i - 30, @BaseDate)),
        DATEADD(DAY, -@i, @BaseDate),
        DATEADD(DAY, -@i, @BaseDate),
        DATEADD(DAY, -@i - 30, @BaseDate)
    );

    SET @i += 1;
END;

