Use Staging_DB
GO

----------------------------------------------
-- Insert sample data into staging tables
----------------------------------------------

----------------------------------------------
-- 1. stg.Customer
----------------------------------------------

truncate table stg.Customer;
insert into stg.Customer (CustomerID, FirstName, LastName, DOB)
values 
('C002','Melissa','Melbourne','19950414'), -- duplicate customer ID. 
('C002','Melissa','Melbourne','19950414'), -- duplicate customer ID. 
('C003','John','Cooper','20250115'), -- DOB in future
('C004','Peter','Parker','20400310'), -- DOB in future
('C005','Tim','Tam','20230711'), -- DOB in future
('C008','Brett','Nodi','19801015AAA'), -- DOB Invalid Format
('C009',NULL,'Lee','19900810'), -- FirstName NULL
('C010','Allan',NULL,'19950101'), -- LastName NULL
(NULL,'Joe','Long','19980312') -- CustomerID NULL

GO

-- 2.0 Run the below script file:

-- Master_Script_DataValidation_BatchRun.sql


-- 3.0 Verify results by comparing them with what was in the Excel spreadsheet:

