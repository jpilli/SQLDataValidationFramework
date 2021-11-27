USE Staging_DB
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

drop procedure if exists [dbo].[usp_DataValidation_DemoRuleset_Tier0_stg_Customer] 
GO

create procedure [dbo].[usp_DataValidation_DemoRuleset_Tier0_stg_Customer] as 
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
set @tableName = 'Customer';
-- Get EntityID to which the validation rules in this stored procedure are associated with
exec [dbo].[usp_DataValidation_GetEntityID] @schemaName, @tableName, @EntityID OUTPUT, @CompositeBusinessKeyDelimiter OUTPUT

set @ValidationTier = 0; /* Make sure to assign appropriate ValidationTier value */

-- Get BatchID to associate the output with
exec [dbo].[usp_DataValidation_CreateOrGetBatchID] @rulesetCode, @BatchID OUTPUT

-------------------
-- 0.0 Prep: Remove previous entries from DataValidationOutput, in preparation for a re-run
-------------------
exec [dbo].[usp_DataValidation_Cleanup_BeforeRerun] @BatchID, @RulesetCode, @EntityID, @ValidationTier

-----------------------------
-- 1.0 Validate for NULL or empty fields
-----------------------------

-- 1.1 CustomerID_Null
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
		t.CustomerID,
		'First Name/Last Name was: ' + isnull(t.FirstName,'NULL') + ' ' + isnull(t.LastName,'NULL')
	from stg.Customer t
	where t.CustomerID is null
end

-- 1.2 FirstName_Null
set @validationRuleCode = 'FirstName_Null'
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
	where t.CustomerID is not null
	and t.FirstName is null
end

-- 1.3 LastName_Null
set @validationRuleCode = 'LastName_Null'
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
	where t.CustomerID is not null
	and t.LastName is null
end

-----------------------------
-- 2.0 Validate for Duplicates
-----------------------------
-- 2.1 CustomerID_Duplicate
set @validationRuleCode = 'CustomerID_Duplicate'
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
	inner join 
	(
		select CustomerID, count(*) dups
		from stg.Customer t
		where t.CustomerID is not null
		group by CustomerID
		having count(*) > 1
	) duplicates
	on t.CustomerID = duplicates.CustomerID
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

-----------------------------
-- 5.0 Validate for format
-----------------------------
-- 5.1 DOB_InvalidFormat
set @validationRuleCode = 'DOB_InvalidFormat'
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
		'DOB value provided was: ' + t.DOB + '; Not in YYYYMMDD format'
	from stg.Customer t
	where t.CustomerID is not null
	and t.DOB is not null
	and try_convert(datetime, t.DOB,112) is null
end

-----------------------------
-- 6.0 Other validations
-----------------------------
-- 6.1 DOB_FutureDate
set @validationRuleCode = 'DOB_FutureDate'
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
		'DOB value provided was: ' + t.DOB
	from stg.Customer t
	where t.CustomerID is not null
	and try_convert(datetime, t.DOB,112) is not null
	and t.DOB > convert(date,getdate());
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


