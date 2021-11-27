USE Staging_DB
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

drop procedure if exists [dbo].[usp_DataValidation_Generate_JOIN_clause_On_BusinessKeys] 
GO

create procedure [dbo].[usp_DataValidation_Generate_JOIN_clause_On_BusinessKeys] 
	@EntityID int,
	@SQLJoinOnBusinessKeys nvarchar(1000) OUTPUT			
as 
/*
Description:
For a given @EntityID, this sp generates JOIN clause on business keys in the staging table.

ATTENTION:
In the calling stored procedures, the below two tables are required to be aliased as below:
(i) staging table: stg
(ii) DataValidationOutput table: dvo
This would only be required when you are calling this stored procedure to get the JOIN clause
on BusinessKeys between a staging table and DataValidationOutput table.

Example output values for @SQLJoinOnBusinessKeys:
Example 1: 
When CustomerID was the business key in the staging table, the OUTPUT value is:
convert(nvarchar(200),stg.[CustomerID]) = dvo.BusinessKeyValue

Example 2: 
When it was a composite business key (CustomerID, AddressSequenceNo) in the staging table
along with '~' as the delimiter while forming the business key value, the OUTPUT value is:
convert(nvarchar(200),stg.[CustomerID])+ '~' + convert(nvarchar(200),stg.[AddressSequenceNo]) = dvo.BusinessKeyValue
*/
begin try

set nocount on;
SET XACT_ABORT ON;

declare 
	@SQLJoinClause nvarchar(1000),
	@ErrorMsg nvarchar(4000)

-- initialise
set @SQLJoinClause = N'';

-- validate input param: @EntityID
if not exists(select * from dbo.DataValidationEntityList where EntityID = @EntityID)
begin
	set @ErrorMsg = N'Couldnot find EntityID: ' + isnull(convert(nvarchar(30),@EntityID),'NULL');
	throw 50001, @ErrorMsg,1;
end

-- See if businessKeys were set up for the given entity
if not exists(select * from dbo.DataValidationBusinessKey dvbk
	inner join dbo.DataValidationEntityList list
	on dvbk.EntityID = list.EntityID
	where dvbk.EntityID = @EntityID)
begin
	set @ErrorMsg = N'No BusinessKeyColumns found for EntityID: ' + isnull(convert(nvarchar(30),@EntityID),'NULL');
	throw 50001, @ErrorMsg,1;
end
else
begin
	-- Generate JOIN clause
	select @SQLJoinClause = 
		@SQLJoinClause + 
		N'+ ''' + isnull(list.CompositeBusinessKeyDelimiter,'') + '''' + ' + convert(nvarchar(200),stg.' + QUOTENAME(dvbk.ColumnName) + ')'
	from dbo.DataValidationBusinessKey dvbk
	inner join dbo.DataValidationEntityList list
	on dvbk.EntityID = list.EntityID
	where dvbk.EntityID = @EntityID
	order by dvbk.BusinessKeyColumnOrder

end

-- Remove the leading CompositeBusinessKeyDelimiter (e.g. '~' + ) from the beginning of the string
select @SQLJoinOnBusinessKeys = Substring(@SQLJoinClause,9,len(@SQLJoinClause) - 1) + ' = dvo.BusinessKeyValue';

END TRY
BEGIN CATCH
	THROW;
END CATCH


GO


