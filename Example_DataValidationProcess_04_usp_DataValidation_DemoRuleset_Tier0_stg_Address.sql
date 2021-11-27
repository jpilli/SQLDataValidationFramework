USE Staging_DB
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

drop procedure if exists [dbo].[usp_DataValidation_DemoRuleset_Tier0_stg_Address] 
GO

create procedure [dbo].[usp_DataValidation_DemoRuleset_Tier0_stg_Address] as 
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
set @tableName = 'Address';
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

-- 1.1 BusinessKey_Null (t.CustomerID + t.AddressSequenceNo)
set @validationRuleCode = 'CustID_or_AddressSeq_Null';
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
		NULL, 
		'CustomerID was: ' + isnull(t.CustomerID,'NULL') + '; AddressSequenceNo was: ' + isnull(convert(nvarchar,t.AddressSequenceNo),'NULL')
	from stg.[Address] t
	where t.CustomerID is null or t.AddressSequenceNo is null
end

-- 1.2 AddressLine1_Null
set @validationRuleCode = 'AddressLine1_Null';
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
		NULL
	from stg.[Address] t
	where t.CustomerID is not null
	and t.AddressSequenceNo is not null
	and AddressLine1 is null
end

-- 1.3 Suburb_Null
set @validationRuleCode = 'Suburb_Null';
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
		NULL
	from stg.[Address] t
	where t.CustomerID is not null
	and t.AddressSequenceNo is not null
	and t.Suburb is null
end

-----------------------------
-- 2.0 Validate for Duplicates
-----------------------------
-- 2.1 Duplicate_business_key
set @validationRuleCode = 'Duplicate_CustID_AddressSeq';
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
		t.CustomerID + @CompositeBusinessKeyDelimiter + convert(varchar(20),t.AddressSequenceNo),
		NULL
	from stg.[Address] t
	inner join 
	(
		select CustomerID, AddressSequenceNo, count(*) dups
		from stg.[Address] 
		where CustomerID is not null
		and AddressSequenceNo is not null
		group by CustomerID, AddressSequenceNo
		having count(*) > 1
	) duplicates
	on t.CustomerID = duplicates.CustomerID
	and t.AddressSequenceNo = duplicates.AddressSequenceNo

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

-- 6.1 PostCode_Invalid
set @validationRuleCode = 'PostCode_Invalid';
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
		t.CustomerID + @CompositeBusinessKeyDelimiter + convert(varchar(20),t.AddressSequenceNo),
		'Actual value provided for PostCode: ' + isnull(t.PostCode,'NULL')
	from stg.[Address] t
	where t.CustomerID is not null
	and t.AddressSequenceNo is not null
	and t.PostCode is not null
	and
	(
		-- Business rule: Postcode expected to be 4 digits long
		try_convert(int, t.PostCode) is null
		or
		len(rtrim(ltrim(t.PostCode))) != 4
	)

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


