Use Staging_DB
GO

begin try

	declare @rulesetCode nvarchar(30);

	set @rulesetCode = 'DemoRuleset';

	-- Validate basic configuration within the data validation framework itself.
	exec dbo.usp_DataValidation_ValidateEntityAndRulesSetup @rulesetCode

	-- Validate data in various staging tables, in the sequential order of tiers.
	exec dbo.usp_DataValidation_DemoRuleset_Tier0_stg_Customer;
	exec dbo.usp_DataValidation_DemoRuleset_Tier0_stg_Account;
	exec dbo.usp_DataValidation_DemoRuleset_Tier0_stg_Address;
	exec dbo.usp_DataValidation_DemoRuleset_Tier01_Multi_Entity;
	exec dbo.usp_DataValidation_DemoRuleset_Tier02_Multi_Entity;
	exec dbo.usp_DataValidation_DemoRuleset_Tier03_Multi_Entity;

	-- update Batch status to successful
	-- Note: Only on setting the status to 'S', the next batch will be assigned a new BatchID.
	--	Else, a re-run would re-use the existing latest batch ID.
	exec dbo.usp_DataValidation_UpdateBatchStatus @rulesetCode, 'S';

	exec dbo.usp_DataValidation_Generate_XML_Output @RulesetCode

end try
begin catch

	-- In the event of errors, update batch status to failed
	exec dbo.usp_DataValidation_UpdateBatchStatus @rulesetCode, 'F';

	THROW;

end catch