USE Staging_DB
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

drop procedure if exists [dbo].[usp_DataValidation_DemoRuleset_Tier02_Multi_Entity] 
GO

create procedure [dbo].[usp_DataValidation_DemoRuleset_Tier02_Multi_Entity] as 
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

set @ValidationTier = 2; /* Make sure to assign appropriate ValidationTier value */

-- Get BatchID to associate the output with
exec [dbo].[usp_DataValidation_CreateOrGetBatchID] @rulesetCode, @BatchID OUTPUT

-------------------
-- 0.0 Prep: Remove previous entries from DataValidationOutput, in preparation for a re-run
-------------------
exec [dbo].[usp_DataValidation_Cleanup_BeforeRerun] @BatchID, @RulesetCode, @EntityID, @ValidationTier

--------------------------------------------------
-- 1.0 Multi-entity level data validation rules
--------------------------------------------------

-- 1.1 Customer_with_invalid_account(s)
set @schemaName = 'stg';
set @tableName = 'Customer';
-- Get EntityID to which this particular validation rule is associated with
exec [dbo].[usp_DataValidation_GetEntityID] @schemaName, @tableName, @EntityID OUTPUT, @CompositeBusinessKeyDelimiter OUTPUT

set @validationRuleCode = 'Customer_with_invalid_account(s)';
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
	inner join stg.Account a
	on t.CustomerID = a.CustomerID
	where t.CustomerID is not null
	and a.IsValid = 0

	-- 1.1.1: Update Staging Table now rather than later, because every validation rule in this proc may point to different table.
	-- Note: Unlike in case of ValidationTier 0, in case of higher validation tiers (i.e ValidationTier >= 1)
	-- make sure to pass a NOT NULL values as @ruleID.
	exec dbo.usp_DataValidation_Mark_Invalid_Rows @RulesetCode, @EntityID, @ValidationTier,@ruleID,0

end

-- 1.2 Customer_with_invalid_address(es)
set @schemaName = 'stg';
set @tableName = 'Customer';
-- Get EntityID to which this particular validation rule is associated with
exec [dbo].[usp_DataValidation_GetEntityID] @schemaName, @tableName, @EntityID OUTPUT, @CompositeBusinessKeyDelimiter OUTPUT

set @validationRuleCode = 'Customer_with_invalid_address(es)';
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
	inner join stg.[Address] ads
	on t.CustomerID = ads.CustomerID
	where t.CustomerID is not null
	and ads.IsValid = 0;

	-- 1.2.1: Update Staging Table now rather than later, because every validation rule in this proc may point to different table.
	-- Note: Unlike in case of ValidationTier 0, in case of higher validation tiers (i.e ValidationTier >= 1)
	-- make sure to pass a NOT NULL values as @ruleID.
	exec dbo.usp_DataValidation_Mark_Invalid_Rows @RulesetCode, @EntityID, @ValidationTier,@ruleID,0

end

END TRY
BEGIN CATCH
	THROW;
END CATCH


GO