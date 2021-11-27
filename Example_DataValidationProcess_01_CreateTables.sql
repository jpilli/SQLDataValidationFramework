/*
Pre-requisite: 
	Staging_DB was already created for this demo. 
	Alternatively, change the database context to any other database of your choice.
*/
USE Staging_DB
GO

-----------------------------------------
-- 0.0 'stg' Schema creation
-----------------------------------------
--create staging schema
IF (NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg')) 
BEGIN
    EXEC ('CREATE SCHEMA [stg] AUTHORIZATION [dbo]')
END
GO

-----------------------------------------
-- 1.0 Staging tables
-----------------------------------------
drop table if exists stg.Customer;
GO
create table stg.Customer
(
	CustomerID varchar(50) NULL,
	FirstName varchar(100) NULL,
	LastName varchar(100) NULL,
	DOB	varchar(30) NULL,
	IsValid bit NOT NULL CONSTRAINT df_stg_customer_isValid DEFAULT(1)
);

drop table if exists stg.Account;
GO
create table stg.Account
(
	AccountID int NULL,
	CustomerID varchar(50) NULL,
	AccountType varchar(1) NULL,
	AccountOpenedDate date NULL,
	AccountClosedDate date NULL, 
	IsValid bit NOT NULL CONSTRAINT df_stg_account_isValid DEFAULT(1)
);

drop table if exists stg.[Address];
GO
create table stg.[Address]
(
	/*
	This table was intentionally designed to have composite business key
	(CustomerID + AddressSequenceNo) to demonstrate how to handle it 
	in this data validation framework
	*/

	CustomerID varchar(50) NULL,
	AddressSequenceNo int NULL,
	AddressType varchar(10) NULL, 
	AddressLine1 varchar(100) NULL,
	AddressLine2 varchar(100) NULL,
	Suburb varchar(100) NULL,
	PostCode varchar(20) NULL, 
	IsValid bit NOT NULL CONSTRAINT df_stg_address_isValid DEFAULT(1)
);

-----------------------------------------
-- 2.0 destination tables
-----------------------------------------
drop table if exists dbo.Customer;
GO
create table dbo.Customer
(
	CustomerID varchar(50) NOT NULL,
	FirstName varchar(100) NOT NULL,
	LastName varchar(100) NOT NULL, 
	DOB	date NULL, 
	constraint pk_dbo_Customer PRIMARY KEY CLUSTERED 
	(
		CustomerID asc
	)
);

drop table if exists dbo.Account;
GO
create table dbo.Account
(
	AccountID int NOT NULL,
	CustomerID varchar(50) NOT NULL, 
	AccountType varchar(1) NOT NULL, 
	AccountOpenedDate date NOT NULL,
	AccountClosedDate date NULL, 
	constraint pk_dbo_Account PRIMARY KEY CLUSTERED 
	(
		AccountID asc
	)
);

drop table if exists dbo.[Address];
GO
create table dbo.[Address]
(
	CustomerID varchar(50) NOT NULL,
	AddressSequenceNo int NOT NULL,
	AddressType varchar(10) NULL, 
	AddressLine1 varchar(100) NOT NULL,
	AddressLine2 varchar(100) NULL,
	Suburb varchar(100) NOT NULL,
	PostCode varchar(20) NULL, 
	constraint pk_dbo_Address PRIMARY KEY CLUSTERED 
	(
		CustomerID asc, AddressSequenceNo asc
	)
);

GO
