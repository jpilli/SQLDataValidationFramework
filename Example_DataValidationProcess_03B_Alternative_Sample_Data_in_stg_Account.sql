Use Staging_DB
GO

----------------------------------------------
-- Insert sample data into staging tables
----------------------------------------------

----------------------------------------------
-- 2. stg.Account
----------------------------------------------

truncate table stg.Account;
insert into stg.Account
(AccountID, CustomerID, AccountType, AccountOpenedDate, AccountClosedDate)
values
(1002,'C007','B','20081015',NULL), -- Duplicate Account 
(1002,'C007','B','20081225',NULL), -- Duplicate Account
(1004,'C008','X','20061210',NULL), -- AccountType_Invalid
(1005,'C009',NULL,'20101117',NULL), -- Account Type NULL
(1006,'C010','B',NULL,NULL), -- AccountOpenedDate NULL
(1007,NULL,'C','20110505','20100707'), -- Customer ID NULL + AccountClosedDatePriorToOpenedDate
(NULL,'C021','A','20121212',NULL) -- Account ID NULL


-- 2.0 Run the below script file:

-- Master_Script_DataValidation_BatchRun.sql


-- 3.0 Verify results by comparing them with what was in the Excel spreadsheet:






