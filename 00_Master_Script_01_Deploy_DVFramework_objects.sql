:ON ERROR EXIT
:SETVAR ScriptFilesPath "E:\Surya\Blogs\DataValidationFramework\SQLScripts\"
:SETVAR DeploymentLogFileName "00_DVFramework_Deployment_Log.txt"
:OUT $(ScriptFilesPath)$(DeploymentLogFileName)
:SETVAR ErrFileName "00_DVFramework_Deployment_ErrorLog.txt"
:ERROR $(ScriptFilesPath)$(ErrFileName)

:R $(ScriptFilesPath)DVFramework_01_CreateTables.sql
:R $(ScriptFilesPath)DVFramework_02_dbo_usp_DataValidation_CheckNecessityOfIsValidColumn.sql
:R $(ScriptFilesPath)DVFramework_02_dbo_usp_DataValidation_Cleanup_BeforeRerun.sql
:R $(ScriptFilesPath)DVFramework_02_dbo_usp_DataValidation_CreateOrGetBatchID.sql
:R $(ScriptFilesPath)DVFramework_02_dbo_usp_DataValidation_Generate_JOIN_clause_On_BusinessKeys.sql
:R $(ScriptFilesPath)DVFramework_02_dbo_usp_DataValidation_Generate_ORDER_BY_clause_on_BusinessKeyCols.sql
:R $(ScriptFilesPath)DVFramework_02_dbo_usp_DataValidation_Generate_WHERE_clause_BusinessKey_NULL.sql
:R $(ScriptFilesPath)DVFramework_02_dbo_usp_DataValidation_Generate_XML_Output.sql
:R $(ScriptFilesPath)DVFramework_02_dbo_usp_DataValidation_GetEntityID.sql
:R $(ScriptFilesPath)DVFramework_02_dbo_usp_DataValidation_GetValidationRule.sql
:R $(ScriptFilesPath)DVFramework_02_dbo_usp_DataValidation_Mark_Invalid_Rows.sql
:R $(ScriptFilesPath)DVFramework_02_dbo_usp_DataValidation_UpdateBatchStatus.sql
:R $(ScriptFilesPath)DVFramework_02_dbo_usp_DataValidation_ValidateEntityAndRulesSetup.sql



