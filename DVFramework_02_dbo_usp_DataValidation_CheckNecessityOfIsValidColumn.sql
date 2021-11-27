use Staging_DB
GO

drop procedure if exists dbo.usp_DataValidation_CheckNecessityOfIsValidColumn;
GO

create procedure dbo.usp_DataValidation_CheckNecessityOfIsValidColumn
	@rulesetCode nvarchar(30)
as 
/*
It is a conditional requirement that a staging table must have a IsValid column
if any of the validation rules are currently enabled and are associated with are of severity level 'E'

The purpose of this stored procedure is to perform the above check and throw an exception
if the check failed.
*/
begin try

	set nocount on;
	SET XACT_ABORT ON;

	/*
	Variables and temp table creation
	*/
	declare @ErrorMsg nvarchar(max);
	declare @offendingEntitiesCSV nvarchar(max) = N'';

	drop table if exists #EntityWithRuleSeverityE;
	create table #EntityWithRuleSeverityE
	(
		EntityID int NOT NULL
	);

	drop table if exists #EntityIDDetails;
	create table #EntityIDDetails
	(
		EntityID int NOT NULL,
		SchemaName nvarchar(128) NOT NULL,
		TableName nvarchar(128) NOT NULL,
		HasIsValidColumn bit NOT NULL CONSTRAINT df_EntityIDDetail_HasIsValidColumn DEFAULT(0)
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

	/* 1.0 Get a list of entities to check
	
		Consider only those entities that have validation rules of severity E and are enabled.
	*/
	insert into #EntityWithRuleSeverityE(EntityID)
	select distinct EntityID
	from dbo.DataValidationRule dvr
	where RulesetCode = @RulesetCode
	and IsEnabled = 1
	and SeverityLevel = 'E'

	/* 2.0 Get Entity details */
	insert into #EntityIDDetails
	(
		EntityID,
		SchemaName,
		TableName
	)
	select DVElist.EntityID, DVElist.SchemaName, DVElist.TableName
	from dbo.DataValidationEntityList DVElist
	inner join #EntityWithRuleSeverityE TempEList
	on DVElist.EntityID = TempEList.EntityID

	/* 3.0 Determine if Entities have IsValid column */
	update e
	set HasIsValidColumn = 
		case
			when c.COLUMN_NAME is null then 0
			else 1
		end
	from #EntityIDDetails e
	left outer join INFORMATION_SCHEMA.columns c
	on e.SchemaName = c.TABLE_SCHEMA
	and e.TableName = c.TABLE_NAME
	and c.COLUMN_NAME = 'IsValid'

	/* 4.0 See if any of the Entities DO NOT have IsValid column, 
		while being associated with validation rules of severity level E
	*/
	if exists(select * from #EntityIDDetails where HasIsValidColumn = 0)
	begin

		/* Make a CSV list of Entity names that DO NOT have IsValid column  */
		select @offendingEntitiesCSV = @offendingEntitiesCSV + e.SchemaName + '.' + e.TableName + ','
		from #EntityIDDetails e
		where HasIsValidColumn = 0

		select @offendingEntitiesCSV = left(@offendingEntitiesCSV, len(@offendingEntitiesCSV) - 1);

		set @ErrorMsg = N'One or more entities did NOT have IsValid column ' + 
			' Whereas, they were set up with validation rules of severity level E: ' + @offendingEntitiesCSV;
		Throw 50001,@ErrorMsg,1;

	end

END TRY
BEGIN CATCH
	THROW;
END CATCH

GO
