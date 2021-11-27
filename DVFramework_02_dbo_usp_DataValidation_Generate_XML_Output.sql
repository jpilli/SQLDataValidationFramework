Use Staging_DB
GO

drop procedure if exists dbo.usp_DataValidation_Generate_XML_Output;
GO

create procedure dbo.usp_DataValidation_Generate_XML_Output @RulesetCode nvarchar(30) as

	/*
	ATTENTION:
	In this stored procedures, the below two tables are required to be aliased as below:
	(i) staging table: stg
	(ii) DataValidationOutput table: dvo

	This was because the utility stored procedure [dbo].[usp_DataValidation_Generate_JOIN_clause_On_BusinessKeys]
	returns the alias names as stg and dvo respectively.

	However, there was one exception. The outer most query had the alias name as 'AffectedRow' instead of stg.
	So, this exception was handled by replacing the 'stg' with 'AffectedRow' in the string returned by the 
	OUTPUT parameter of the above mentioned utility stored procedure.

	Tip: When a column value is NULL, the XML would exclude such column value from XML output
	*/
begin

	SET NOCOUNT ON;

	/*
	Section 0: Declare variables
	*/
	declare @ErrorMsg nvarchar(4000);
	declare @LatestBatchID int;
	declare 
		@CurrentRowID int = 0,
		@MaxRowID int = 0,
		@currentEntityID int,
		@currentSchemaName nvarchar(128),
		@currentTableName nvarchar(128),
		@SQLJoinOnBusinessKeys nvarchar(1000),
		@SQLJoinOnBusinessKeysAliasModified nvarchar(1000),
		@SQLWhereClauseBusinessKeyNULL nvarchar(1000),
		@SQLORDERBYClauseOnBusinessKeyColumns nvarchar(1000);

	declare 
		@SQLQuery_Part01 nvarchar(max),
		@SQLQuery_Part02 nvarchar(max),
		@SQLQuery_Part03 nvarchar(max),
		@SQLQuery_Part04 nvarchar(max),
		@SQLQuery_Final nvarchar(max);

	/*
	Section 1: Validate input parameters
	*/

	/* 1.1 Validate input param (@rulesetCode) for NULL*/
	if (@rulesetCode is null)
	begin
		set @ErrorMsg = N'@rulesetCode cannot be NULL ' ;
		Throw 50001,@ErrorMsg,1;
	end

	/* 1.2 Validate input param (@rulesetCode) to see if it has any validation rules configured*/
	if not exists(select * from dbo.DataValidationRule where RulesetCode = @rulesetCode)
	begin
		set @ErrorMsg = N'Invalid @rulesetCode. No validation rules found for this @rulesetCode: ' + @rulesetCode;
		Throw 50001,@ErrorMsg,1;
	end

	/*
	Section 2: Get LatestBatchID, only if it had status as SUCCESSFUL
	*/

	/* 2.1 Get the latest BatchID for the given rulesetCode */
	select @LatestBatchID = max(BatchID) 
	from dbo.DataValidationBatch 
	where RulesetCode = @RulesetCode

	/* 2.2 @LatestBatchID will be null when no batch entries were found */
	if (@LatestBatchID is null)
	begin
		set @LatestBatchID = -1;
	end

	/* 2.3 Generate XML only when the latest batch status is successful
		We wouldn't want to generate output when a batch failed due to runtime errors.
		If a batch failed, it's likely the validation output was incomplete.
	*/
	if not exists (
		select [Status]
		from dbo.DataValidationBatch
		where BatchID = @LatestBatchID
		and [Status] = 'S'
	)
	begin
		set @ErrorMsg = N'The latest batch of RulesetCode: (' + ISNULL(@RulesetCode,'NULL') 
			+ ') didnot have a batch status of SUCCESSFUL. The latest Batch ID was: ' 
			+ isnull(convert(nvarchar(30),@LatestBatchID),'NULL');
		throw 50001, @ErrorMsg,1;
	end

	/*
	Section 3: Given the @RulesetCode, get a list of Entities that are associated with it.
	*/
	drop table if exists #EntityList;
	create table #EntityList
	(
		RowID int NOT NULL identity(1,1),
		RulesetCode nvarchar(30) NOT NULL,
		EntityID int NOT NULL,
		SchemaName nvarchar(128) NOT NULL,
		TableName nvarchar(128) NOT NULL
	)

	insert into #EntityList(RulesetCode, EntityID, SchemaName, TableName)
	select distinct dvr.RulesetCode, entityList.EntityID, entityList.SchemaName, entityList.TableName
	from dbo.DataValidationRule dvr
	inner join dbo.DataValidationEntityList entityList
	on dvr.EntityID = entityList.EntityID
	where dvr.RulesetCode = @RulesetCode;

	/* Section 4: Remove previous XML output for the same batch, if any */
	delete from dbo.DataValidationOutputXML where BatchID = @LatestBatchID

	/*
	Section 5: Iterate through list of entities and generate XML output for each entity
	and write to a database table
	*/
	set @CurrentRowID = 1;
	select @MaxRowID = count(*) from #EntityList;
	
	while (@CurrentRowID <= @MaxRowID)
	begin

		/* 5.1 Capture current entity (staging table's) attributes into variables.*/
		select @currentEntityID = EntityID, @currentSchemaName = SchemaName, @currentTableName = TableName
		from #EntityList
		where RowID = @CurrentRowID

		/* 5.2 Generate JOIN clause on business keys between the currrent staging table and DataValidationOutput table */
		exec [dbo].[usp_DataValidation_Generate_JOIN_clause_On_BusinessKeys] 
			@currentEntityID,
			@SQLJoinOnBusinessKeys OUTPUT

		/* 5.3 Modify @SQLJoinOnBusinessKeys to replace 'stg.' with 'AffectedRow.' */
		select @SQLJoinOnBusinessKeysAliasModified = replace(@SQLJoinOnBusinessKeys,'stg.','AffectedRow.')
		
		/* 5.4 Generate WHERE clause for scenarios where the business key was NULL */
		exec [dbo].[usp_DataValidation_Generate_WHERE_clause_BusinessKey_NULL] 
			@currentEntityID,
			@SQLWhereClauseBusinessKeyNULL OUTPUT

		/* 5.5 Generate ORDER BY clause on business key columns for sorting the final output in XML */
		exec [dbo].[usp_DataValidation_Generate_ORDER_BY_clause_on_BusinessKeyCols] 
			@currentEntityID,
			@SQLORDERBYClauseOnBusinessKeyColumns OUTPUT		

		/* 5.6 Prepare SQL query that would generate XML output  */
		/*
			The overall logic in the below dynamic SQL is as below:
	
			Step 1: Firstly determine the RuleIDs that the entity is associated with.
			This will help with narrowing down in matching rows in DataValidationOutput table.
	
			Step 2: Determine the latest successful batch ID for the Ruleset.
			No point parameterising the BatchID. Because even though the DataValidationOutput
			table may have results from multiple batches, the staging data represents just the
			latest data.

			Step 3: Determine the distinct businessKeyValues before you join back to 
			the staging table to get entity details.

			Step 4: Join it back to staging table to get affected rows by the latest validation 
			processing batch (it covers severity E as well as W).
			Note: Make sure to join on BatchID as well as BusinessKeyValue to return the output of 
			latest successfully completed batch only.

			Step 5: Append staging table rows that have business Key as NULL
			There wasn't any easy way to also include business Key columns that were NULL.
			That's why, as a work around, additional output column IsBusinessKeyNull was introduced in XML.
		*/
		select @SQLQuery_Part01 = 
		'INSERT INTO dbo.DataValidationOutputXML([BatchID],SchemaName,TableName,XMLOutput) ' + CHAR(13)
		+ 'SELECT ' + convert(nvarchar(30),@LatestBatchID) + ' as BatchID, ''' + @currentSchemaName + ''' as schemaName, ''' + @currentTableName + ''' as TableName,' + CHAR(13)
		+ '( ' + CHAR(13)
		+ 'SELECT AffectedRow.*, ' + CHAR(13) 
		+ '( ' + CHAR(13)
		+ CHAR(9) + 'SELECT DISTINCT dvo.RuleID as RuleID, dvr.ValidationRuleCode as ValidationRuleCode,  ' + CHAR(13)
		+ CHAR(9) + 'dvr.SeverityLevel as SeverityLevel, dvr.ValidationTier as ValidationTier, ' + CHAR(13)
		+ CHAR(9) + 'dvr.RulesetCode as RulesetCode, ' + CHAR(13)
		+ CHAR(9) + 'dvo.ValidationMessage as ValidationMessage ' + CHAR(13)
		+ CHAR(9) + 'FROM dbo.DataValidationOutput dvo /* N.B: The alias must be "dvo". Read the note in the header section of this stored procedure */ ' + CHAR(13)
		+ CHAR(9) + 'INNER JOIN dbo.DataValidationRule dvr ' + CHAR(13)
		+ CHAR(9) + 'ON dvo.RuleID = dvr.RuleID ' + CHAR(13)
		+ CHAR(9) + '/* Explicitly convert numeric data types to nvarchar, just in case the referenced column in staging table wasnot string*/' + CHAR(13)
		+ CHAR(9) + 'WHERE ' + @SQLJoinOnBusinessKeysAliasModified + CHAR(13) 
		+ CHAR(9) + 'AND dvo.BatchID = AffectedRow.BatchID ' + CHAR(13) 
		+ CHAR(9) + 'ORDER BY dvr.ValidationTier, dvo.RuleID ' + CHAR(13) 
		+ CHAR(9) + 'FOR XML RAW, ROOT(''BrokenRules''),TYPE ' + CHAR(13) 
		+ ')' + CHAR(13) 
		+ 'FROM ' 
		
		select @SQLQuery_Part02 = 
		'( ' + CHAR(13)
		+ '	SELECT  cast(NULL as varchar(10)) as IsBusinessKeyNull, ' + CHAR(13) 
		+ '	dvo.BusinessKeyValue as BusinessKeyValue, ' + CHAR(13)
		+ '	stg.*, ' + CHAR(13)
		+ '	dvo.BatchID ' + CHAR(13)
		+ '	FROM ' + @currentSchemaName + '.' + @currentTableName + ' as stg '  + CHAR(13) /* N.B: The alias must be "stg". Read the note in the header section of this stored procedure */
		+ '	INNER JOIN ' + CHAR(13)
		+ '	( ' + CHAR(13)
		+ '		SELECT DISTINCT dvo1.BatchID, dvo1.BusinessKeyValue ' + CHAR(13)
		+ '		FROM dbo.DataValidationOutput dvo1 ' + CHAR(13)
		+ '		WHERE dvo1.BatchID = ' + convert(nvarchar(30),@LatestBatchID) + CHAR(13)
		+ '		AND dvo1.RuleID in ' + CHAR(13)
		+ '		( ' + CHAR(13)
		+ '			SELECT RuleID ' + CHAR(13)
		+ '			FROM dbo.DataValidationEntityList list ' + CHAR(13)
		+ '			INNER JOIN dbo.DataValidationRule dvr ' + CHAR(13)
		+ '			ON list.EntityID = dvr.EntityID ' + CHAR(13)
		+ '			WHERE list.SchemaName = ''' + @currentSchemaName + '''' + CHAR(13) 
		+ '			AND list.TableName = ''' + @currentTableName + '''' + CHAR(13) 
		+ '			AND dvr.RulesetCode = ''' + @rulesetCode + '''' + CHAR(13)
		+ '		)' + CHAR(13)
		+ '	) dvo ' + CHAR(13) /* N.B: The alias must be "dvo". Read the note in the header section of this stored procedure */
		+ '	ON ' + @SQLJoinOnBusinessKeys + CHAR(13)

		select @SQLQuery_Part03 = 
		/* Note: 
			When businessKeyValue is NULL, we will not be able to join the
			DataValidationOutput (DVO) table to staging table.
			So, even though DVO table's ValidationMessage column may have 
			additional info in it, unfortunately we wouldn't be able to retrieve it for XML. 
			However, the entire row from staging table itself can be extracted into XML. 
		*/
		'	UNION ALL ' + CHAR(13) + CHAR(13)
		+ '	select ''Yes'' as IsBusinessKeyNull, ' + CHAR(13) 
		+ '	cast(NULL as nvarchar(4000)) as BusinessKeyValue, ' + CHAR(13)
		+ '	stg2.*, ' + CHAR(13)
		+ '	cast(' + convert(nvarchar(30),@LatestBatchID) + ' as int) as BatchID' + CHAR(13)
		+ '	from ' + @currentSchemaName + '.' + @currentTableName + ' as stg2 ' + CHAR(13)
		+ '	where ' + @SQLWhereClauseBusinessKeyNULL + ' /* BusinessKey NULL scenarios */ ' + CHAR(13)
		+ ') AffectedRow /* AffectedRow could be due to Severity E and/or W) */  '

		select @SQLQuery_Part04 = 
		' order by ' + @SQLORDERBYClauseOnBusinessKeyColumns + CHAR(13)
		+ 'for XML Auto, Elements, ROOT(''' + @currentSchemaName + '.' + @currentTableName + '''), TYPE  ' + CHAR(13)
		+ ')'

		select @SQLQuery_Final =
			@SQLQuery_Part01 + CHAR(13) +
			@SQLQuery_Part02 + CHAR(13) +
			@SQLQuery_Part03 + CHAR(13) +
			@SQLQuery_Part04 + CHAR(13);

		--select @SQLQuery_Final;
		EXECUTE sp_executesql @SQLQuery_Final

		set @CurrentRowID = @CurrentRowID + 1;

	end
end

GO