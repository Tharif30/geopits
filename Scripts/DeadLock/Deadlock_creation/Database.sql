-- Create test database
CREATE DATABASE BlockingTestDB;
GO
USE BlockingTestDB;
GO

-- Create tables for blocking/deadlock simulation
CREATE TABLE Accounts (
    AccountID INT PRIMARY KEY,
    Balance MONEY
);

CREATE TABLE Transactions (
    TransactionID INT PRIMARY KEY IDENTITY,
    AccountID INT,
    Amount MONEY,
    CreatedAt DATETIME DEFAULT GETDATE()
);

-- Insert some dummy records
INSERT INTO Accounts (AccountID, Balance)
VALUES (72, 4000), (67, 5000), (58, 6000);
