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
('C001', NULL, NULL, '13122021'), -- One row that broke multiple validation rules. Additionally: Invalid customer + 0 account + 0 address records
('C002','Melissa','Melbourne','19950414'), -- duplicate customer ID. Additionally: Invalid customer + 0 account + 0 address records
('C002','Melissa','Melbourne','19950414'), -- duplicate customer ID. Additionally: Invalid customer + 0 account + 0 address records
('C003','John','Cooper','20250115'), -- DOB in future, multiple rows breaking the same rule: Additionally: Invalid customer + 0 account + 0 address records
('C004','Peter','Parker','20400310'), -- DOB in future, multiple rows breaking the same rule: Additionally: Invalid customer + 0 account + 0 address records
('C005','Tim','Tam','20230711'), -- DOB in future, multiple rows breaking the same rule: Additionally: Invalid customer + 0 account + 0 address records
('C006','Indiana','Zones','19950606'), -- valid customer + valid account + valid address
('C007','Matt','Matilda','19970707'), -- valid customer + invalid account + valid address
('C008','Brett','Nodi','19801015'), -- valid customer + valid account + invalid address
('C009','Matthew','Lee','19900810'), -- valid customer + invalid account + invalid address
('C010','Allan',NULL,'19950101'), -- Invalid customer. So, account and address rendered invalid
(NULL,'Joe','Long','19980312') -- Invalid customer (CustomerID NULL). No account, no address

----------------------------------------------
-- 2. stg.Account
----------------------------------------------

truncate table stg.Account;
insert into stg.Account
(AccountID, CustomerID, AccountType, AccountOpenedDate, AccountClosedDate)
values
(1001,'C006','A','20050505',NULL), -- valid customer + valid account + valid address
(1002,'C007','X','20081015',NULL), -- valid customer + invalid 1 of 2 accounts + valid address
(1003,'C007','B','20081225',NULL), -- valid customer + valid 2 of 2 accounts + valid address
(1004,'C008','C','20061210',NULL), -- valid customer + valid account + invalid address
(1005,'C009','X','20101117',NULL), -- valid customer + invalid account + invalid address
(1006,'C010','B','20090909',NULL), -- Invalid customer. So, account and address rendered invalid
(1007,'C020','C','20110505','20100707'), -- orphan account with no linked customer + invalid AccountClosedDate
(NULL,'C021','A','20121212',NULL), -- orphan account with no linked customer + NULL account ID (1st)
(NULL,'C022','A','20140202',NULL) -- orphan account with no linked customer + NULL account ID (2nd)

----------------------------------------------
-- 3. stg.Address
----------------------------------------------

/*
This table was intentionally designed to have composite business key
(CustomerID + AddressSequenceNo) to demonstrate how to handle it 
in this data validation framework
*/
truncate table stg.[Address];
insert into stg.[Address]
(CustomerID, AddressSequenceNo, AddressType, AddressLine1, AddressLine2, Suburb, PostCode)
values
('C006',1,'R','1 George Street',NULL,'Sydney','2000'), -- valid customer + valid account + valid address
('C007',1,'P','GPO Box 4567',NULL,'Sydney','2000'), -- valid customer + invalid 1 of 2 accounts + valid address
('C008',1,'P','GPO Box 1234',NULL,NULL,'2000'), -- valid customer + valid account + invalid address
('C009',1,'R','1 Thomas St',NULL,'Hornsby','2077ABC'), -- valid customer + invalid account + invalid address
('C010',1,'R','23 Park Street',NULL,'Melbourne','3001'), -- Invalid customer. So, account and address rendered invalid
('C020',1,'P','1 George',NULL,'Chatswood','2077') -- Orphan address

GO
