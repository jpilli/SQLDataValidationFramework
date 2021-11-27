Use Staging_DB
GO

drop procedure if exists [dbo].[usp_DataValidation_GetValidationRule]
GO
create procedure [dbo].[usp_DataValidation_GetValidationRule] 
	@rulesetCode nvarchar(30),
	@entityID int, 
	@validationRuleCode nvarchar(200),
	@ruleID int OUTPUT,
	@IsRuleEnabled bit OUTPUT
as  
begin try 

	set nocount on;

	declare @ErrorMsg as nvarchar(1000);

	select 
		@ruleID = RuleID, 
		@IsRuleEnabled = IsEnabled
	from dbo.DataValidationRule
	where RulesetCode = @rulesetCode
	and EntityID = @entityID
	and ValidationRuleCode = @validationRuleCode

	if (@ruleID is null)
	begin
		set @ErrorMsg = 'Unable to find RuleID for ' + 
			'@rulesetCode: ' + isnull(@rulesetCode,'NULL') +
			', @EntityID: ' + convert(nvarchar(20),isnull(@EntityID,'NULL')) +  
			', @validationRuleCode: ' + isnull(@validationRuleCode,'NULL');

		Throw 50001,@ErrorMsg,1;
	end

end try
begin catch
	Throw;
end catch

GO
