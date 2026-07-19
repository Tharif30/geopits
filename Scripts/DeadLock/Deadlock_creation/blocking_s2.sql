USE BlockingTestDB;
SELECT *
FROM Accounts WITH (NOLOCK)  -- won’t block
WHERE AccountID = 1;

-- This will get blocked
UPDATE Accounts
SET Balance = Balance - 50
WHERE AccountID = 1;
