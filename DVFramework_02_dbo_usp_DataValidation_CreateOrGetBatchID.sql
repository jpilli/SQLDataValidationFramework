USE Staging_DB
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

drop procedure if exists [dbo].[usp_DataValidation_CreateOrGetBatchID] 
GO

create procedure [dbo].[usp_DataValidation_CreateOrGetBatchID] 
	@rulesetCode nvarchar(30),
	@currentBatchID int OUTPUT
as 
/*
A new batch will be created only under the following circumstances:
For a given @rulesetCode,
(i) when no records were found in dbo.DataValidationBatch
(ii)when the latest existing record had a batch status of 'S' (Successful)

In either of these circumstances, a new batch record is created with a status of 'R' (Running)

If the latest record's status was not 'S', then the latest existig batch ID of that @rulesetCode 
will be re-used for resuming the failed batch or re-starting from the beginning.
*/
begin try

	set nocount on;
	SET XACT_ABORT ON;

	declare @ErrorMsg as nvarchar(1000),
		@LatestBatchStatus as nvarchar(1),
		@LatestBatchID as int;

	/* Validate input param (@rulesetCode) for NULL*/
	if (@rulesetCode is null)
	begin
		set @ErrorMsg = N'@rulesetCode cannot be NULL ' ;
		Throw 50001,@ErrorMsg,1;
	end

	/* Validate input param (@rulesetCode) to see if it has any validation rules configured*/
	if not exists(select * from dbo.DataValidationRule where RulesetCode = @rulesetCode)
	begin
		set @ErrorMsg = N'Invalid @rulesetCode. No validation rules found for this @rulesetCode: ' + @rulesetCode;
		Throw 50001,@ErrorMsg,1;
	end

	/* Get latest batch status */
	select top 1 @LatestBatchID = BatchID, @LatestBatchStatus = [Status]
	from dbo.DataValidationBatch
	where RulesetCode = @rulesetCode
	order by BatchID desc

	/* Insert into dbo.DataValidationBatch, if appropriate */
	if (@LatestBatchStatus = 'S' or @LatestBatchStatus is null)
	begin
		insert into dbo.DataValidationBatch(RulesetCode, StartDate, [Status], StatusDescription)
		values(@rulesetCode,getdate(),'R','Running')

		select @currentBatchID = SCOPE_IDENTITY();
	end
	else
	begin
		set @currentBatchID = @LatestBatchID;
	end

END TRY
BEGIN CATCH
	THROW;
END CATCH


GO