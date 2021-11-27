USE Staging_DB
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

drop procedure if exists [dbo].[usp_DataValidation_DemoRuleset_Tier01_Multi_Entity] 
GO

create procedure [dbo].[usp_DataValidation_DemoRuleset_Tier01_Multi_Entity] as 
begin try

set nocount on;
SET XACT_ABORT ON;

declare @RulesetCode varchar(30),
		@EntityID int,
		@schemaName nvarchar(128),
		@tableName nvarchar(128),
		@BatchID int,
		@CompositeBusinessKeyDelimiter nvarchar(1),
		@validationRuleCode nvarchar(100),
		@RuleID int,
		@IsRuleEnabled bit,
		@ValidationTier tinyint;

set @RulesetCode = 'DemoRuleset';
/* In case of ValidationTier 1 and above, 
	the @schemaName and @tableName values are assigned at individual validation query level 
*/
set @ValidationTier = 1; /* Make sure to assign appropriate ValidationTier value */

-- Get BatchID to associate the output with
exec [dbo].[usp_DataValidation_CreateOrGetBatchID] @rulesetCode, @BatchID OUTPUT

-------------------
-- 0.0 Prep: Remove previous entries from DataValidationOutput, in preparation for a re-run
-------------------
exec [dbo].[usp_DataValidation_Cleanup_BeforeRerun] @BatchID, @RulesetCode, @EntityID, @ValidationTier

--------------------------------------------------
-- 1.0 Multi-entity level data validation rules
--------------------------------------------------
-- 1.1 Customer_without_account
set @schemaName = 'stg';
set @tableName = 'Customer';
-- Get EntityID to which this particular validation rule is associated with
exec [dbo].[usp_DataValidation_GetEntityID] @schemaName, @tableName, @EntityID OUTPUT, @CompositeBusinessKeyDelimiter OUTPUT

set @validationRuleCode = 'Customer_without_account';
exec [dbo].[usp_DataValidation_GetValidationRule] @rulesetCode, @EntityID, @validationRuleCode, @ruleID OUTPUT, @IsRuleEnabled OUTPUT

if (@IsRuleEnabled = 1)
begin
	insert into dbo.DataValidationOutput
	(
		BatchID,
		RuleID,
		BusinessKeyValue,
		ValidationMessage
	)
	select 
		@BatchID,
		@RuleID,
		t.CustomerID,
		NULL
	from stg.Customer t
	left outer join stg.Account a
	on t.CustomerID = a.CustomerID
	where t.CustomerID is not null
	and a.CustomerID is null

	-- 1.1.1: Update Staging Table now rather than later, because every validation rule in this proc may point to different table.
	-- Note: Unlike in case of ValidationTier 0, in case of higher validation tiers (i.e ValidationTier >= 1)
	-- make sure to pass a NOT NULL values as @ruleID.
	exec dbo.usp_DataValidation_Mark_Invalid_Rows @RulesetCode, @EntityID, @ValidationTier,@ruleID,0

end

-- 1.2 Customer_without_address
set @schemaName = 'stg';
set @tableName = 'Customer';
-- Get EntityID to which this particular validation rule is associated with
exec [dbo].[usp_DataValidation_GetEntityID] @schemaName, @tableName, @EntityID OUTPUT, @CompositeBusinessKeyDelimiter OUTPUT

set @validationRuleCode = 'Customer_without_address';
exec [dbo].[usp_DataValidation_GetValidationRule] @rulesetCode, @EntityID, @validationRuleCode, @ruleID OUTPUT, @IsRuleEnabled OUTPUT

if (@IsRuleEnabled = 1)
begin
	insert into dbo.DataValidationOutput
	(
		BatchID,
		RuleID,
		BusinessKeyValue,
		ValidationMessage
	)
	select 
		@BatchID,
		@RuleID,
		t.CustomerID,
		NULL
	from stg.Customer t
	left outer join stg.[Address] ads
	on t.CustomerID = ads.CustomerID
	where t.CustomerID is not null
	and ads.CustomerID is null

	-- 1.2.1: Update Staging Table now rather than later, because every validation rule in this proc may point to different table.
	-- Note: Unlike in case of ValidationTier 0, in case of higher validation tiers (i.e ValidationTier >= 1)
	-- make sure to pass a NOT NULL values as @ruleID.
	exec dbo.usp_DataValidation_Mark_Invalid_Rows @RulesetCode, @EntityID, @ValidationTier,@ruleID,0

end

-- 1.3 Account_with_NonExistent_Customer (Account_Orphan)
set @schemaName = 'stg';
set @tableName = 'Account';
-- Get EntityID to which this particular validation rule is associated with
exec [dbo].[usp_DataValidation_GetEntityID] @schemaName, @tableName, @EntityID OUTPUT, @CompositeBusinessKeyDelimiter OUTPUT

set @validationRuleCode = 'Account_with_NonExistent_Customer';
exec [dbo].[usp_DataValidation_GetValidationRule] @rulesetCode, @EntityID, @validationRuleCode, @ruleID OUTPUT, @IsRuleEnabled OUTPUT

if (@IsRuleEnabled = 1)
begin
	insert into dbo.DataValidationOutput
	(
		BatchID,
		RuleID,
		BusinessKeyValue,
		ValidationMessage
	)
	select 
		@BatchID,
		@RuleID,
		t.AccountID,
		'Account with non-existent parent. CustomerID: ' + t.CustomerID
	from stg.Account t
	left outer join stg.Customer c
	on t.CustomerID = c.CustomerID
	where t.AccountID is not null
	and t.CustomerID is not null
	and c.CustomerID is null

	-- 1.3.1: Update Staging Table now rather than later, because every validation rule in this proc may point to different table.
	-- Note: Unlike in case of ValidationTier 0, in case of higher validation tiers (i.e ValidationTier >= 1)
	-- make sure to pass a NOT NULL values as @ruleID.
	exec dbo.usp_DataValidation_Mark_Invalid_Rows @RulesetCode, @EntityID, @ValidationTier,@ruleID,0

end

-- 1.4 Address_with_NonExistent_Customer (Orphan_Address)
set @schemaName = 'stg';
set @tableName = 'Address';
-- Get EntityID to which this particular validation rule is associated with
exec [dbo].[usp_DataValidation_GetEntityID] @schemaName, @tableName, @EntityID OUTPUT, @CompositeBusinessKeyDelimiter OUTPUT

set @validationRuleCode = 'Address_with_NonExistent_Customer';
exec [dbo].[usp_DataValidation_GetValidationRule] @rulesetCode, @EntityID, @validationRuleCode, @ruleID OUTPUT, @IsRuleEnabled OUTPUT

if (@IsRuleEnabled = 1)
begin
	insert into dbo.DataValidationOutput
	(
		BatchID,
		RuleID,
		BusinessKeyValue,
		ValidationMessage
	)
	select 
		@BatchID,
		@RuleID,
		t.CustomerID + @CompositeBusinessKeyDelimiter + convert(varchar(20),t.AddressSequenceNo) as BusinessKeyValue,
		'Address with non-existent parent. CustomerID : ' + t.CustomerID
	from stg.[Address] t
	left outer join stg.Customer c
	on t.CustomerID = c.CustomerID
	where t.CustomerID is not null
	and t.AddressSequenceNo is not null
	and c.CustomerID is null

	-- 1.4.1: Update Staging Table now rather than later, because every validation rule in this proc may point to different table.
	-- Note: Unlike in case of ValidationTier 0, in case of higher validation tiers (i.e ValidationTier >= 1)
	-- make sure to pass a NOT NULL values as @ruleID.
	exec dbo.usp_DataValidation_Mark_Invalid_Rows @RulesetCode, @EntityID, @ValidationTier,@ruleID,0

end

END TRY
BEGIN CATCH
	THROW;
END CATCH

GO