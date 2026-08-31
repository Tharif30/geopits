----------------------------
--tbl_user_lifecycle – BEFORE_CONSENT
----------------------------
BEGIN TRANSACTION;

;WITH cte AS (
    SELECT TOP (1000) *
    FROM tbl_user_lifecycle
    WHERE usr_lifecycle_status = 'BEFORE_CONSENT'
      AND usr_lifecycle_user_subscription_id IN (
            SELECT subscription_id
            FROM tbl_user_subscriptions
            WHERE subscription_addedat < '2026-01-01'
              AND subscription_status IS NULL
      )
    ORDER BY usr_lifecycle_createddate
)
DELETE FROM cte;

COMMIT TRANSACTION;
----------------------------
--tbl_user_lifecycle – GRACE
----------------------------
BEGIN TRANSACTION;

;WITH cte AS (
    SELECT TOP (1000) *
    FROM tbl_user_lifecycle
    WHERE usr_lifecycle_status = 'grace'
    ORDER BY usr_lifecycle_createddate
)
DELETE FROM cte;

COMMIT TRANSACTION;
----------------------------
--tbl_ads2shistory
----------------------------
BEGIN TRANSACTION;

;WITH cte AS (
    SELECT TOP (1000) *
    FROM tbl_ads2shistory
    WHERE history_subscription_id IN (
        SELECT subscription_id
        FROM tbl_user_subscriptions
        WHERE subscription_addedat < '2026-01-01'
          AND subscription_status IS NULL
    )
    ORDER BY history_createdat
)
DELETE FROM cte;

COMMIT TRANSACTION;
----------------------------
--tbl_user_subscriptions
----------------------------
BEGIN TRANSACTION;

;WITH cte AS (
    SELECT TOP (1000) *
    FROM tbl_user_subscriptions
    WHERE subscription_addedat < '2026-01-01'
      AND subscription_status IS NULL
    ORDER BY subscription_addedat
)
DELETE FROM cte;

COMMIT TRANSACTION;


