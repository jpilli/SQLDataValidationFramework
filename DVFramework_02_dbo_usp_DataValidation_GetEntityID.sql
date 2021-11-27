Use Staging_DB
GO

drop procedure if exists [dbo].[usp_DataValidation_GetEntityID]
GO
create procedure [dbo].[usp_DataValidation_GetEntityID] 
	@schemaName nvarchar(128),
	@tableName nvarchar(128),
	@EntityID int OUTPUT,
	@CompositeBusinessKeyDelimiter char(1) OUTPUT
as  
begin try 

	set nocount on;

	declare @ErrorMsg as nvarchar(1000);

	select 
		@EntityID = EntityID, 
		@CompositeBusinessKeyDelimiter = CompositeBusinessKeyDelimiter
	from dbo.DataValidationEntityList list
	where SchemaName = @schemaName
	and TableName = @tableName;

	if (@EntityID is null)
	begin
		set @ErrorMsg = N'Unable to find @EntityID for ' + 
			'@schemaName: ' + isnull(@schemaName,'NULL') + ' and ' +
			'@tableName: ' + isnull(@tableName,'NULL') + ' in dbo.DataValidationEntityList';

		Throw 50001,@ErrorMsg,1;
	end

end try
begin catch
	Throw;
end catch

GO
