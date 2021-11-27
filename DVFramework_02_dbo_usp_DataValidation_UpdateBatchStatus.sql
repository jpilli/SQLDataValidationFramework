USE Staging_DB
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

drop procedure if exists [dbo].[usp_DataValidation_UpdateBatchStatus] 
GO

create procedure [dbo].[usp_DataValidation_UpdateBatchStatus] 
	@rulesetCode nvarchar(30),
	@status nvarchar(1)
as 
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

	/* Update latest batch status, if not already 'S' */
	if (@LatestBatchStatus != 'S')
	begin
		update dvb
		set [status] = @status,
			StatusDescription = 
				case
					when @status = 'S' then 'Successful'
					when @status = 'F' then 'Failed'
					when @status = 'R' then 'Running'
					else 'Unknown status: ' + @status
				end,
			EndDate = getdate()
		from dbo.DataValidationBatch dvb
		where RulesetCode = @rulesetCode
		and BatchID = @LatestBatchID
	end

END TRY
BEGIN CATCH
	THROW;
END CATCH


GO