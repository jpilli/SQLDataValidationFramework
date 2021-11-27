USE Staging_DB
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

drop procedure if exists [dbo].[usp_DataValidation_DemoRuleset_Tier0_stg_Account] 
GO

create procedure [dbo].[usp_DataValidation_DemoRuleset_Tier0_stg_Account] as 
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
set @schemaName = 'stg';
set @tableName = 'Account';
-- Get EntityID to which the validation rules in this stored procedure are associated with
exec [dbo].[usp_DataValidation_GetEntityID] @schemaName, @tableName, @EntityID OUTPUT, @CompositeBusinessKeyDelimiter OUTPUT

set @ValidationTier = 0; /* Make sure to assign appropriate ValidationTier value */

-- Get BatchID to associate the output with
exec [dbo].[usp_DataValidation_CreateOrGetBatchID] @rulesetCode, @BatchID OUTPUT

-------------------
-- 0.0 Prep: Remove previous entries from DataValidationOutput, in preparation for a re-run
-------------------
Exec [dbo].[usp_DataValidation_Cleanup_BeforeRerun] @BatchID, @RulesetCode, @EntityID, @ValidationTier

-----------------------------
-- 1.0 Validate for NULL or empty fields
-----------------------------

-- 1.1 AccountID_Null
set @validationRuleCode = 'AccountID_Null';
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
		'Related Customer ID was: ' + isnull(t.CustomerID,'NULL')
	from stg.Account t
	where AccountID is null
end

-- 1.2 CustomerID_Null
set @validationRuleCode = 'CustomerID_Null';
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
		NULL 
	from stg.Account t
	where AccountID is not null
	and CustomerID is null
end

-- 1.3 AccountType_Null
set @validationRuleCode = 'AccountType_Null';
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
		NULL
	from stg.Account t
	where AccountID is not null
	and AccountType is null
end

-- 1.4 AccountOpenedDate_Null
set @validationRuleCode = 'AccountOpenedDate_Null';
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
		NULL
	from stg.Account t
	where AccountID is not null
	and AccountOpenedDate is null
end

-----------------------------
-- 2.0 Validate for Duplicates
-----------------------------
-- 2.1 AccountID_Duplicate
set @validationRuleCode = 'AccountID_Duplicate';
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
		NULL
	from stg.Account t
	inner join 
	(
		select AccountID, count(*) dups
		from stg.Account t
		where AccountID is not null
		group by AccountID
		having count(*) > 1
	) duplicates
	on t.AccountID = duplicates.AccountID
end

/*
-----------------------------
-- 3.0 Validate for Truncation
-----------------------------
-- None
*/
/*
-----------------------------
-- 4.0 Validate for Data types
-----------------------------
-- None
*/

/*
-----------------------------
-- 5.0 Validate for format
-----------------------------
-- None
*/

-----------------------------
-- 6.0 Other validations
-----------------------------

-- 6.1 AccountClosedDatePriorToOpenedDate
set @validationRuleCode = 'AccountClosedDatePriorToOpenedDate';
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
		'Actual values provided - ' + 
		'AccountOpenedDate: ' + convert(varchar(30),t.AccountOpenedDate) + '; ' + 
		'AccountClosedDate: ' + convert(varchar(30),t.AccountClosedDate)  
	from stg.Account t
	where t.AccountID is not null
	and t.AccountOpenedDate > t.AccountClosedDate
end

-- 6.2 AccountType_Invalid
set @validationRuleCode = 'AccountType_Invalid';
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
		'Actual value provided: AccountType: ' + t.AccountType 
	from stg.Account t
	where AccountID is not null
	and t.AccountType is not null
	and t.AccountType not in ('A','B','C')
end

/*
	99.0 Update Staging Table's IsValid flag, 
		if any of the validation rules broken were of severity level E (Error)

		In case of validationTier = 0, @RuleID param value is not applicable.
*/
	exec dbo.usp_DataValidation_Mark_Invalid_Rows @RulesetCode, @EntityID, @ValidationTier,NULL,0

END TRY
BEGIN CATCH
	THROW;
END CATCH


GO


