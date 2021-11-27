Use Staging_DB
GO
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
('C006',1,'R',NULL,NULL,'Sydney','2000'), -- AddressLine1 NULL
('C007',1,'P','GPO Box 4567',NULL,'Sydney','2000'), -- Duplicate business key
('C007',1,'P','GPO Box 4567',NULL,'Sydney','2000'), -- Duplicate business key
('C008',1,'P','GPO Box 1234',NULL,NULL,'2000'), -- Suburb NULL
('C009',1,'R','1 Thomas St',NULL,'Hornsby','2077ABC'), -- Invalid Postcode
(NULL,1,'P','1 George',NULL,'Chatswood','2077') -- Business Key NULL

GO

-- 2.0 Run the below script file:

-- Master_Script_DataValidation_BatchRun.sql


-- 3.0 Verify results by comparing them with what was in the Excel spreadsheet:






