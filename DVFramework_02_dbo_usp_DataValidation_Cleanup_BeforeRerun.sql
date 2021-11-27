USE Staging_DB
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

drop procedure if exists [dbo].[usp_DataValidation_Cleanup_BeforeRerun] 
GO

create procedure [dbo].[usp_DataValidation_Cleanup_BeforeRerun] 
	@batchID int,
	@rulesetCode varchar(30),
	@entityID int,
	@validationTier tinyint
as 
/*
The purpose of this stored procedure is to delete previous output based on latest BatchID, if any

In this regard, two points to note:
1. If the validation tier = 0 (i.e. validations at individual entity level), then
	- delete output of all rules at the validation tier 0, for the GIVEN entity in that RulesetCode.

2. If the validation tier > 0 (i.e. validations at multi-entity level), then
	- delete output of all rules at the validation tier N, for EVERY entity in that RulesetCode.

*/
begin try

	set nocount on;
	SET XACT_ABORT ON;

	/* If it were ValidationTier = 0, 
		delete output of all rules at the validation tier 0, for the GIVEN entity in that RulesetCode 
	*/
	if @validationTier = 0
	begin
		delete from dvo
		from dbo.DataValidationOutput dvo
		inner join dbo.DataValidationRule dvr
		on dvo.RuleID = dvr.RuleID
		where dvr.RulesetCode = @rulesetCode
		and dvr.EntityID = @entityID
		and dvr.ValidationTier = @validationTier
		and dvo.BatchID >= @batchID 
	end
	else
	/* If it were ValidationTier > 0, 
		delete output of all rules at the validation tier N, for EVERY entity in that RulesetCode 
	*/
	begin
		delete from dvo
		from dbo.DataValidationOutput dvo
		inner join dbo.DataValidationRule dvr
		on dvo.RuleID = dvr.RuleID
		where dvr.RulesetCode = @rulesetCode
		--and dvr.EntityID = @EntityID
		and dvr.ValidationTier = @validationTier
		and dvo.BatchID >= @batchID
	end

END TRY
BEGIN CATCH
	THROW;
END CATCH


GO