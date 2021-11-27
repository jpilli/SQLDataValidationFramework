:ON ERROR EXIT
:SETVAR ScriptFilesPath "E:\Surya\Blogs\DataValidationFramework\SQLScripts\"
:SETVAR DeploymentLogFileName "00_Example_DataValidationProcess_Deployment_Log.txt"
:OUT $(ScriptFilesPath)$(DeploymentLogFileName)
:SETVAR ErrFileName "00_Example_DataValidationProcess_Deployment_ErrorLog.txt"
:ERROR $(ScriptFilesPath)$(ErrFileName)

:R $(ScriptFilesPath)Example_DataValidationProcess_01_CreateTables.sql
:R $(ScriptFilesPath)Example_DataValidationProcess_02_Example_DataValidation_Rules.sql
:R $(ScriptFilesPath)Example_DataValidationProcess_03_Example_Data_in_staging_tables.sql
:R $(ScriptFilesPath)Example_DataValidationProcess_04_usp_DataValidation_DemoRuleset_Tier0_stg_Account.sql
:R $(ScriptFilesPath)Example_DataValidationProcess_04_usp_DataValidation_DemoRuleset_Tier0_stg_Address.sql
:R $(ScriptFilesPath)Example_DataValidationProcess_04_usp_DataValidation_DemoRuleset_Tier0_stg_Customer.sql
:R $(ScriptFilesPath)Example_DataValidationProcess_04_usp_DataValidation_DemoRuleset_Tier01_Multi_Entity.sql
:R $(ScriptFilesPath)Example_DataValidationProcess_04_usp_DataValidation_DemoRuleset_Tier02_Multi_Entity.sql
:R $(ScriptFilesPath)Example_DataValidationProcess_04_usp_DataValidation_DemoRuleset_Tier03_Multi_Entity.sql

