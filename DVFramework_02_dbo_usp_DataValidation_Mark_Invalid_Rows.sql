USE Staging_DB
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

drop procedure if exists [dbo].[usp_DataValidation_Mark_Invalid_Rows] 
GO

create procedure [dbo].[usp_DataValidation_Mark_Invalid_Rows] 
	@RulesetCode nvarchar(30),
	@EntityID int,
	@ValidationTier tinyint,
	@RuleID int = NULL,
	@Debug bit = 0
as 
/*
The purpose of this stored procedure is to mark in the staging table,
the IsValid flag to FALSE for those rows that had broken business rules of severity level 'E' (Error).

This stored procedure broadly caters for two scenarios:
1. When @ValidationTier = 0 (i.e. single-entity level validations)
2. When @ValidationTier >= 1 (i.e. multi-entity level validations)

The main difference between the two is that:
- when @ValidationTier = 0, this stored proc considers all the validation rules of severity E, 
	that were associated with the given entity.
- when @ValidationTier >= 1, this stored proc considers only the given validation rule (if severity E)
	while marking invalid rows.

Notes:
1. Only in case of validation rules of severity level = 'E', 
	mark appropriate rows as invalid in staging table.
2. To cater for possible NULLs in business key in staging table, 
	LEFT OUTER JOIN was used in the below queries, especially when validation tier = 0,
	assuming the validation for NULL values in business key columns happens in this tier only.
*/
begin try

set nocount on;
SET XACT_ABORT ON;

	declare 
		@ErrorMsg nvarchar(4000),
		@BatchID int,
		@RulesetCodeInBrackets nvarchar(32),
		@SQL_Part1_UPDATE_SET nvarchar(1000),
		@SQL_Part2_FROM_Stg_table nvarchar(1000),
		@SQL_Part3_JOIN_Type nvarchar(1000),
		@SQL_Part4_JOIN_DVOutputInvalidRows nvarchar(1000),
		@SQL_Part5_ON nvarchar(1000),
		@SQL_Part6_WHERE_BizKey_Matched_In_DVOutput nvarchar(1000),
		@SQL_Part7_WHERE_BizKey_NULL_In_Stg nvarchar(1000),
		@SQLJoinOnBusinessKeys nvarchar(1000),
		@SQLWhereClauseBusinessKeyNULL nvarchar(1000),
		@UpdateSQLComplete nvarchar(max),
		@EntityName nvarchar(256),
		@IsValidColumnExists bit,
		@HasEntityGotSeverityERules bit;

	/*
	----------------------------------------------------------
	0.0 Validate input parameters
	----------------------------------------------------------
	*/
	/* 0.1 - validate @RulesetCode and @EntityID */
	select @RulesetCodeInBrackets = QUOTENAME(@RulesetCode);

	if not exists(select * from dbo.DataValidationRule 
		where '[' + RulesetCode + ']' = @RulesetCodeInBrackets
		and EntityID = @EntityID)
	begin
		set @ErrorMsg = N'Invalid @RulesetCode: ' + isnull(@RulesetCode,'NULL') 
			+ ' and/or @EntityID: ' + 
			isnull(convert(nvarchar(30),@EntityID),'NULL');
		throw 50001, @ErrorMsg,1;
	end

	/* 0.2 - validate @ValidationTier */
	if (@ValidationTier is null)
	begin
		set @ErrorMsg = N'@ValidationTier cannot be NULL';
		throw 50001, @ErrorMsg,1;
	end

	/* 0.3 - validate @RuleID, when provided */
	if (@RuleID is not null)
	begin
		if not exists(select * from dbo.DataValidationRule 
			where RulesetCode = @RulesetCode
			and EntityID = @EntityID
			and RuleID = @RuleID)
		begin
			set @ErrorMsg = N'Unable to find RuleID: ' 
				+ isnull(convert(nvarchar(30),@RuleID),'NULL')
				+ ' under the RulesetCode: ' + @RulesetCode
				+ ' and EntityID: ' + isnull(convert(nvarchar(30),@EntityID),'NULL');
			throw 50001, @ErrorMsg,1;
		end
	end

	/* 0.4 If @ValidationTier >= 1, then @RuleID cannot be null */
	if (@ValidationTier >= 1 and @RuleID is null)
	begin
		set @ErrorMsg = N'Invalid @RuleID provided. It cannot be NULL when the @ValidationTier >= 1';
		throw 50001, @ErrorMsg,1;
	end

	/* 0.5 If a given EntityID has validation rule(s) of severity level 'E',
		then the corresponding staging table must have 'IsValid' column.
	*/
	/* 0.5.1 IsValid column present on the given staging table? */
	if exists(
	select * from INFORMATION_SCHEMA.columns
	where '[' + TABLE_SCHEMA + ']' =  
			(SELECT QUOTENAME(SchemaName)
			from dbo.DataValidationEntityList
			where EntityID = @EntityID)
	and '[' + TABLE_NAME + ']' =  
			(SELECT QUOTENAME(TableName)
			from dbo.DataValidationEntityList
			where EntityID = @EntityID)
	and COLUMN_NAME = 'IsValid'
	)
	begin
		set @IsValidColumnExists = 1
	end
	else
	begin
		set @IsValidColumnExists = 0
	end

	/* 0.5.2 Does the given entityID has validation rules of severity level E? */
	if exists (select *
		from dbo.DataValidationRule dvr
		where EntityID = @EntityID
		and IsEnabled = 1
		and SeverityLevel = 'E')
	begin
		set @HasEntityGotSeverityERules = 1
	end
	else
	begin
		set @HasEntityGotSeverityERules = 0
	end 

	/* 0.5.3 If severity E rules are present for that entity, then the corresponding staging table
		must have IsValid column*/
	if ((@HasEntityGotSeverityERules = 1) and (@IsValidColumnExists = 0))
	begin
		/*
		IsValid column would be a requirement only when the target staging table has validation
		rules of severity E.
		*/
		set @ErrorMsg = N'The entityID: ' + convert(nvarchar(30),@EntityID) 
		+ ' was associated with validation rules of severity level E.'
		+ ' But, the corresponding staging table didnot have IsValid column.';
		throw 50001, @ErrorMsg,1;
	end
	else if (@HasEntityGotSeverityERules = 0)
	begin
		/*
		When the entity has no Severity E rules attached to it, no point executing this stored proc.

		Despite this fact, if this stored proc is still called, and if the staging table didn't have 
		IsValid column, then this stored proc would fail. Because, the UPDATE query
		in this stored procedure expects the staging table to have IsValid column.

		So, to cater for these two scenarios, return from here by skipping the execution of the rest
		of this stored procedure.
		*/
		Print 'Existing this proc as the given entity has not got any validation rules of severity E';
		RETURN 0;
	end

	/*
	----------------------------------------------------------
	1.0 Get latest BatchID value:
	----------------------------------------------------------
	*/
	exec [dbo].[usp_DataValidation_CreateOrGetBatchID] @rulesetCode, @BatchID OUTPUT

	/*
	----------------------------------------------------------
	2.0 Generate SQL for marking staging table's IsValid column
	----------------------------------------------------------
	*/

	/* 2.1 Prepare part 1 of SQL update statement */
	set @SQL_Part1_Update_Set = 
		N' UPDATE stg ' + CHAR(10) + CHAR(13) +
		N' SET IsValid = 0' + CHAR(10) + CHAR(13);

	/* 2.2 Get staging table name */
	select @EntityName = QUOTENAME(SchemaName) + N'.' + QUOTENAME(TableName)
	from dbo.DataValidationEntityList
	where EntityID = @EntityID

	set @SQL_Part2_FROM_Stg_table = N' FROM ' + @EntityName + ' stg ' + CHAR(10) + CHAR(13);

	/* 2.3 INNER/LEFT OUTER JOIN 
		In case of @ValidationTier = 0, LEFT OUTER joining is being used to also cater
		for scenarios where the business key in the staging table is NULL and therefore
		cannot join to DVOutput table
	*/
	if (@ValidationTier = 0)
	begin
		set @SQL_Part3_JOIN_Type = N' LEFT OUTER JOIN ' + CHAR(10) + CHAR(13);
	end
	else
	begin
		set @SQL_Part3_JOIN_Type = N' INNER JOIN  ' + CHAR(10) + CHAR(13);
	end
	
	/* 2.4 Get invalid Rows from dbo.DataValidationOutput, that were associated with Rules of severity type 'E' (Error)

	*/
	if (@ValidationTier = 0)
	begin
		set @SQL_Part4_JOIN_DVOutputInvalidRows = N' (' + CHAR(10) + CHAR(13)
			+ '		select distinct dvo1.BusinessKeyValue ' + CHAR(10) + CHAR(13) 
			+ '		from dbo.DataValidationOutput dvo1 ' + CHAR(10) + CHAR(13)
			+ '		inner join dbo.DataValidationRule dvr ' + CHAR(10) + CHAR(13)
			+ '		on dvr.RulesetCode = ''' + @RulesetCode + '''' + CHAR(10) + CHAR(13)
			+ '		and dvr.EntityID = ' + convert(nvarchar(30),@EntityID) + CHAR(10) + CHAR(13)
			+ '		and dvr.ValidationTier = ' + convert(nvarchar(30),@ValidationTier) + CHAR(10) + CHAR(13)
			+ '		and dvr.RuleID = dvo1.RuleID ' + CHAR(10) + CHAR(13)
			+ '		and dvo1.BatchID = ' + convert(nvarchar(30),@BatchID) + CHAR(10) + CHAR(13)
			+ '		and dvr.SeverityLevel = ''E''' + CHAR(10) + CHAR(13)
			+ ') as dvo ' + CHAR(10) + CHAR(13);
	end
	else
	begin
		set @SQL_Part4_JOIN_DVOutputInvalidRows = N' (' + CHAR(10) + CHAR(13)
			+ '		select distinct dvo1.BusinessKeyValue ' + CHAR(10) + CHAR(13) 
			+ '		from dbo.DataValidationOutput dvo1 ' + CHAR(10) + CHAR(13)
			+ '		inner join dbo.DataValidationRule dvr ' + CHAR(10) + CHAR(13)
			+ '		on dvr.RuleID = dvo1.RuleID ' + CHAR(10) + CHAR(13)
			+ '		and dvr.RuleID = ' + convert(nvarchar(30),@RuleID) + CHAR(10) + CHAR(13)
			+ '		and dvo1.BatchID = ' + convert(nvarchar(30),@BatchID) + CHAR(10) + CHAR(13)
			+ '		and dvr.SeverityLevel = ''E''' + CHAR(10) + CHAR(13)
			+ ') as dvo ' + CHAR(10) + CHAR(13);
	end

	/* 2.5 ON clause */
	exec [dbo].[usp_DataValidation_Generate_JOIN_clause_On_BusinessKeys] @EntityID, @SQLJoinOnBusinessKeys OUTPUT
	set @SQL_Part5_ON = N' ON ' + @SQLJoinOnBusinessKeys + CHAR(10) + CHAR(13);;

	/* 2.6 @SQL_Part6_WHERE_BizKey_Matched_In_DVOutput
		Skip from updating rows that were already marked as invalid 
	*/
	set @SQL_Part6_WHERE_BizKey_Matched_In_DVOutput = 
		N' WHERE (stg.IsValid = 1' + CHAR(10) + CHAR(13) + 
		N' AND dvo.BusinessKeyValue is not null )' + CHAR(10) + CHAR(13);

	/* 2.7 @SQL_Part7_WHERE_BizKey_NULL_In_Stg */
	if (@ValidationTier = 0)
	begin
		exec dbo.usp_DataValidation_Generate_WHERE_clause_BusinessKey_NULL @EntityID, @SQLWhereClauseBusinessKeyNULL OUTPUT		
		set @SQL_Part7_WHERE_BizKey_NULL_In_Stg = N' OR ' + CHAR(10) + CHAR(13) + 
		'(' + @SQLWhereClauseBusinessKeyNULL + ')' + CHAR(10) + CHAR(13);
	end
	else
	begin
		set @SQL_Part7_WHERE_BizKey_NULL_In_Stg = N''
	end
	
	/*
	----------------------------------------------------------
	3.0 Execute/Print out UPDATE SQL complete statement
	----------------------------------------------------------
	*/
	set @UpdateSQLComplete = 
		@SQL_Part1_UPDATE_SET
		+ @SQL_Part2_FROM_Stg_table
		+ @SQL_Part3_JOIN_Type
		+ @SQL_Part4_JOIN_DVOutputInvalidRows
		+ @SQL_Part5_ON
		+ @SQL_Part6_WHERE_BizKey_Matched_In_DVOutput
		+ @SQL_Part7_WHERE_BizKey_NULL_In_Stg

	if (@Debug = 1)
	begin
		Print @UpdateSQLComplete;
	end
	else
	begin
		exec sp_executesql @UpdateSQLComplete;
	end

END TRY
BEGIN CATCH
	THROW;
END CATCH


GO


