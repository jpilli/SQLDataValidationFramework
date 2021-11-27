use Staging_DB
GO

drop procedure if exists dbo.usp_DataValidation_ValidateEntityAndRulesSetup;
GO

create procedure dbo.usp_DataValidation_ValidateEntityAndRulesSetup
	@rulesetCode nvarchar(30)
as 
/*
The purpose of this stored procedure is to verify if the entities and validation rules
were configured correctly within the data validation framework:

1. [Schema].[Table] as specified in dbo.DataValidationRule must existing
	in the database
2. Every entity as listed in dbo.DataValidationRule must have at least 
	one businesskey column specified in dbo.DataValidationBusinessKey table
3. Every business key that was specified in dbo.DataValidationBusinessKey
	must be present the corresponding table in the database
4. For every entity under a given @rulesetCode, if any validation rules of severity 'E' 
	exist, then the corresponding staging table must have IsValid column
*/
begin try

	set nocount on;
	SET XACT_ABORT ON;

	/*
	Variables and temp table creation
	*/
	declare @ErrorMsg nvarchar(max);
	declare @offendingEntitiesCSV nvarchar(max) = N'';

	drop table if exists #Entities;
	create table #Entities
	(
		EntityID int NOT NULL
	);

	/*
	0.0 Validate input params
	*/

	/* 0.1 Validate input param (@rulesetCode) to see if it has any validation rules configured*/
	if @rulesetCode is null
	begin
		set @ErrorMsg = N'@rulesetCode cannot be NULL.';
		Throw 50001,@ErrorMsg,1;
	end
	else
	begin
		if not exists(select * from dbo.DataValidationRule where RulesetCode = @rulesetCode)
		begin
			set @ErrorMsg = N'Invalid @rulesetCode. No validation rules found for this @rulesetCode: ' + @rulesetCode;
			Throw 50001,@ErrorMsg,1;
		end
	end 

	/* 1: Get a list of entities to check
	
		Note: Ignore those entities that have all their validation rules were disabled
	*/
	insert into #Entities(EntityID)
	select distinct EntityID
	from dbo.DataValidationRule dvr
	where RulesetCode = @RulesetCode
	and IsEnabled = 1

	/* Check 1: Check if those entities specified in data validation framework configuration
		actually exist in the database
	 
		If not, make a CSV list of such offending entities and throw an exception.
	*/
	select @offendingEntitiesCSV = @offendingEntitiesCSV + list.SchemaName + '.' + list.TableName + ','
	from dbo.DataValidationEntityList list
	inner join #Entities e
	on list.EntityID = e.EntityID
	left outer join INFORMATION_SCHEMA.columns c
	on list.SchemaName = c.TABLE_SCHEMA
	and list.TableName = c.TABLE_NAME
	where c.TABLE_NAME is null

	if len(@offendingEntitiesCSV) > 0
	begin

		select @offendingEntitiesCSV = left(@offendingEntitiesCSV, len(@offendingEntitiesCSV) - 1);
		set @ErrorMsg = N'One or more entities as set up in dbo.DataValidationEntityList were NOT ' + 
			' actually found in the database: ' + @offendingEntitiesCSV;
		Throw 50001,@ErrorMsg,1;
	end

	/* Check 2: Make sure every entity as set up in dbo.DataValidationEntityList has atleast
		one business key set up in dbo.DataValidationBusinessKey table

		If not, make a CSV list of such offending entities and throw an exception.
	*/
	select @offendingEntitiesCSV = @offendingEntitiesCSV + list.SchemaName + '.' + list.TableName + ','
	from dbo.DataValidationEntityList list
	inner join #Entities e
	on list.EntityID = e.EntityID
	left outer join 
	(
		select distinct EntityID
		from dbo.DataValidationBusinessKey 
	) bizKey
	on list.EntityID = bizKey.EntityID
	where bizKey.EntityID is null

	if len(@offendingEntitiesCSV) > 0
	begin

		select @offendingEntitiesCSV = left(@offendingEntitiesCSV, len(@offendingEntitiesCSV) - 1);
		set @ErrorMsg = N'One or more entities as set up in dbo.DataValidationEntityList did NOT ' + 
			' have at least one business key in dbo.DataValidationBusinessKey: ' + @offendingEntitiesCSV;
		Throw 50001,@ErrorMsg,1;
	end

	/* Check 3: Make sure the business keys as set up in dbo.DataValidationBusinessKey actually
		exist in the database.
	
		If not, make a CSV list of such offending entities and throw an exception.
	*/
	select @offendingEntitiesCSV = @offendingEntitiesCSV + list.SchemaName + '.' + list.TableName + '.' + bizKey.ColumnName + ','
	from dbo.DataValidationEntityList list
	inner join #Entities e
	on list.EntityID = e.EntityID
	inner join 
	(
		select EntityID, ColumnName
		from dbo.DataValidationBusinessKey 
	) bizKey
	on list.EntityID = bizKey.EntityID
	left outer join INFORMATION_SCHEMA.columns c
	on list.SchemaName = c.TABLE_SCHEMA
	and list.TableName = c.TABLE_NAME
	and bizKey.ColumnName = c.COLUMN_NAME
	where c.COLUMN_NAME is null

	if len(@offendingEntitiesCSV) > 0
	begin

		select @offendingEntitiesCSV = left(@offendingEntitiesCSV, len(@offendingEntitiesCSV) - 1);
		set @ErrorMsg = N'One or more businessKeys as set up in dbo.DataValidationBusinessKey were NOT ' + 
			' found in the database: ' + @offendingEntitiesCSV;
		Throw 50001,@ErrorMsg,1;
	end

	/* Check 4: See if a staging table has IsValid column, if that entity were set up
		with validation rules of Severity Level E 
	
		Note: If this condition isn't satisfied, then the called stored procedure itself would throw an exception.
	*/
	exec dbo.usp_DataValidation_CheckNecessityOfIsValidColumn @rulesetCode

END TRY
BEGIN CATCH
	THROW;
END CATCH

GO
