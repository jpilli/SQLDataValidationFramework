Use Staging_DB
GO
----------------------------------------------
-- Insert sample data validation rules
----------------------------------------------

delete from dvo 
from dbo.DataValidationOutput dvo
inner join dbo.DataValidationRule dvr
on dvo.RuleID = dvr.RuleID
inner join dbo.DataValidationEntityList list
on dvr.EntityID = list.EntityID
where list.EntityID in(1,2,3) ;

delete from dvr
from dbo.DataValidationRule dvr
inner join dbo.DataValidationEntityList list
on dvr.EntityID = list.EntityID
where list.EntityID in(1,2,3) ;

delete from dvbk from dbo.DataValidationBusinessKey dvbk
inner join dbo.DataValidationEntityList list
on dvbk.EntityID = list.EntityID
where list.EntityID in(1,2,3) ;

delete from dbo.DataValidationEntityList where EntityID in(1,2,3)

-------------------------------
-- Populate DataValidationEntityList
-------------------------------
insert into dbo.DataValidationEntityList(EntityID,SchemaName,TableName,CompositeBusinessKeyDelimiter)
values
(1,'stg','Customer',NULL),
(2,'stg','Account',NULL),
(3,'stg','Address','~')

-------------------------------
-- Populate DataValidationBusinessKey
-------------------------------
insert into dbo.DataValidationBusinessKey([EntityID],[BusinessKeyColumnOrder],[ColumnName])
values
(1,1,'CustomerID'),
(2,1,'AccountID'),
(3,1,'CustomerID'),
(3,2,'AddressSequenceNo')
------------------------------------------------------------------------

declare @ValidationTier int;
---------------------------------------------------------------------------------------------------
-- A. Individual entity level business rules (i.e. Tier 0)
---------------------------------------------------------------------------------------------------
--------------------------------------
-- A.1 stg.Customer
--------------------------------------
set @ValidationTier = 0
insert into dbo.DataValidationRule(RuleID,RulesetCode,ValidationTier,EntityID,ValidationRuleCode,ValidationRuleDesc,SeverityLevel,IsEnabled)
values
(1,'DemoRuleset',@ValidationTier,1,'CustomerID_Null','CustomerID cannot be null','E',1),
(2,'DemoRuleset',@ValidationTier,1,'FirstName_Null','FirstName cannot be null','E',1),
(3,'DemoRuleset',@ValidationTier,1,'LastName_Null','LastName cannot be null','E',1),
(4,'DemoRuleset',@ValidationTier,1,'DOB_InvalidFormat','Date of Birth - required format: YYYYMMDD','E',1),
(5,'DemoRuleset',@ValidationTier,1,'DOB_FutureDate','Date of Birth cannot be a future date','W',1),
(6,'DemoRuleset',@ValidationTier,1,'CustomerID_Duplicate','Duplicate CustomerIDs were found','E',1)

--------------------------------------
-- A.2 stg.Account
--------------------------------------
set @ValidationTier = 0
insert into dbo.DataValidationRule(RuleID,RulesetCode,ValidationTier,EntityID,ValidationRuleCode,ValidationRuleDesc,SeverityLevel,IsEnabled)
values
(11,'DemoRuleset',@ValidationTier,2,'AccountID_Null','AccountID cannot be null','E',1),
(12,'DemoRuleset',@ValidationTier,2,'CustomerID_Null','Parent(CustomerID) cannot be null','E',1),
(13,'DemoRuleset',@ValidationTier,2,'AccountType_Null','AccountType cannot be null','E',1),
(14,'DemoRuleset',@ValidationTier,2,'AccountOpenedDate_Null','AccountOpenedDate cannot be null','E',1),
(15,'DemoRuleset',@ValidationTier,2,'AccountType_Invalid','AccountType is expected to be either A or B or C','E',1),
(16,'DemoRuleset',@ValidationTier,2,'AccountClosedDatePriorToOpenedDate','AccountClosedDate cannot be later than AccountOpenedDate','W',1),
(17,'DemoRuleset',@ValidationTier,2,'AccountID_Duplicate','Duplicate AccountIDs were found','E',1)

--------------------------------------
-- A.3 stg.Address
--------------------------------------
set @ValidationTier = 0
insert into dbo.DataValidationRule(RuleID,RulesetCode,ValidationTier,EntityID,ValidationRuleCode,ValidationRuleDesc,SeverityLevel,IsEnabled)
values
(21,'DemoRuleset',@ValidationTier,3,'CustID_or_AddressSeq_Null','CustomerID and AddressSequenceNo cannot be null','E',1),
(22,'DemoRuleset',@ValidationTier,3,'AddressLine1_Null','AddressLine1 cannot be null','E',1),
(23,'DemoRuleset',@ValidationTier,3,'Suburb_Null','Suburb cannot be null','E',1),
(24,'DemoRuleset',@ValidationTier,3,'PostCode_Invalid','PostCode contained non-numeric characters or incomplete','W',1),
(25,'DemoRuleset',@ValidationTier,3,'Duplicate_CustID_AddressSeq','Duplicates were found on (CustomerID + AddressSequenceNo)','E',1)

---------------------------------------------------------------------------------------------------
-- B. Multi-entity/Cross-entity level business rules
---------------------------------------------------------------------------------------------------

-------------------------
-- B.1 Tier 1
-------------------------
set @ValidationTier = 1
insert into dbo.DataValidationRule(RuleID,RulesetCode,ValidationTier,EntityID,ValidationRuleCode,ValidationRuleDesc,SeverityLevel,IsEnabled)
values
(31,'DemoRuleset',@ValidationTier,1,'Customer_without_account','Customer record without any child(account) records found','E',1),
(32,'DemoRuleset',@ValidationTier,1,'Customer_without_address','Customer record without any child(address) records found','E',1),
--(33,'DemoRuleset',@ValidationTier,2,'Account_without_Customer','Orphan Account was found without a parent(Customer)','E',1),
--(34,'DemoRuleset',@ValidationTier,3,'Address_without_Customer','Orphan Address was found without a parent(Customer)','E',1)
(33,'DemoRuleset',@ValidationTier,2,'Account_with_NonExistent_Customer','Orphan Account was found without a parent(Customer)','E',1),
(34,'DemoRuleset',@ValidationTier,3,'Address_with_NonExistent_Customer','Orphan Address was found without a parent(Customer)','E',1)

-------------------------
-- B.2 Tier 2
-------------------------
set @ValidationTier = 2
insert into dbo.DataValidationRule(RuleID,RulesetCode,ValidationTier,EntityID,ValidationRuleCode,ValidationRuleDesc,SeverityLevel,IsEnabled)
values
(41,'DemoRuleset',@ValidationTier,1,'Customer_with_invalid_account(s)','Customer record has one or more invalid accounts','E',1),
(42,'DemoRuleset',@ValidationTier,1,'Customer_with_invalid_address(es)','Customer record has one or more invalid addresses','E',1)

-------------------------
-- B.3 Tier 3
-------------------------
set @ValidationTier = 3
insert into dbo.DataValidationRule(RuleID,RulesetCode,ValidationTier,EntityID,ValidationRuleCode,ValidationRuleDesc,SeverityLevel,IsEnabled)
values
(51,'DemoRuleset',@ValidationTier,2,'Account_invalidated_due_to_invalid_parent','Account record was rendered invalid as its parent(Customer) was invalid','E',1),
(52,'DemoRuleset',@ValidationTier,3,'Address_invalidated_due_to_invalid_parent','Address record was rendered invalid as its parent(Customer) was invalid','E',1)

GO
