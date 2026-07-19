USE BlockingTestDB;
BEGIN TRAN;
UPDATE Accounts
SET Balance = Balance + 10
WHERE AccountID = 1;

-- Wait a few seconds, then run:
UPDATE Transactions
SET Amount = Amount + 5
WHERE AccountID = 1;
-- Don’t commit yet

