Exec [dbadb].[dbo].[tbl_user_hits_Archive] --succeded
Exec [dbadb].[dbo].[tbl_ads2shistory_Archive]--succeded
Exec [dbadb].[dbo].[tbl_user_lifecycle_Archive]--succeded
Exec [dbadb].[dbo].[tbl_user_subscriptions_Archive] --succeded

i have to deltwe this records which satisfied the below condition
/*Before Consent Entry delete*/

select count(1) from tbl_user_subscriptions tus where tus.subscription_addedat < '2026-01-01' and tus.subscription_status is null
select count(1) from tbl_user_lifecycle tul where tul.usr_lifecycle_user_subscription_id in (select subscription_id from tbl_user_subscriptions tus where tus.subscription_addedat < '2026-01-01' and tus.subscription_status is null) and usr_lifecycle_status='BEFORE_CONSENT'
 

/*Grace Entry Delete*/

select count(1) from tbl_user_lifecycle tul where tul.usr_lifecycle_status = 'grace'

1. tbl_user_hits (Child table)
o	Independent table with no dependencies on other tables.
2. tbl_ads2shistory (Child table)
•	References:
o	tbl_user_subscriptions (via history_subscription_id)
3. tbl_user_lifecycle (Child table)
•	References:
o	tbl_user_subscriptions (via usr_lifecycle_user_subscription_id)
4. tbl_user_subscriptions (Parent table)
•	Referenced by:
o	tbl_user_lifecycle
o	tbl_ads2shistory

Which orde should i follow here for deletion process



