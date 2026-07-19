USE BlockingTestDB;
BEGIN TRAN;
UPDATE Accounts
SET Balance = Balance + 100
WHERE AccountID = 1;
-- Don’t commit/rollback yet

--ROLLBACK TRAN;
