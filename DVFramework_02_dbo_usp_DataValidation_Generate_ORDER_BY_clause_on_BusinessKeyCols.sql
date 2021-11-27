
USE Staging_DB
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

drop procedure if exists [dbo].[usp_DataValidation_Generate_ORDER_BY_clause_on_BusinessKeyCols] 
GO

create procedure [dbo].[usp_DataValidation_Generate_ORDER_BY_clause_on_BusinessKeyCols] 
	@EntityID int,
	@SQLORDERBYClauseOnBusinessKeyColumns nvarchar(1000) OUTPUT			
as 
/*

Example values for OUTPUT parameter @SQLORDERBYClauseOnBusinessKeyColumns:
Example 1: When CustomerID is the businesskey, the OUTPUT value will be:
"[CustomerID]"

Example 2: When it is the composite business key (e.g. [CustomerID], [AddressSequenceNo]),
the OUTPUT value will be:
"[CustomerID],[AddressSequenceNo]"

*/
begin try

set nocount on;
SET XACT_ABORT ON;

declare 
	@SQLOrderByClause nvarchar(1000),
	@ErrorMsg nvarchar(4000)

set @SQLOrderByClause = N'';

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
	-- generate WHERE clause to check if the business key values were NULL
	select @SQLOrderByClause = @SQLOrderByClause + N',' + QUOTENAME(dvbk.ColumnName)
	from dbo.DataValidationBusinessKey dvbk
	where EntityID = @EntityID
	order by BusinessKeyColumnOrder
end

-- Remove the leading ' , ' from the beginning of the string
select @SQLORDERBYClauseOnBusinessKeyColumns = Substring(@SQLOrderByClause,2,len(@SQLOrderByClause) - 1);

END TRY
BEGIN CATCH
	THROW;
END CATCH


GO


