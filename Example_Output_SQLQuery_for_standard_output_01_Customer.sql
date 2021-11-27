
Use Staging_DB
GO

select dvr.RulesetCode, list.SchemaName, list.TableName, dvr.ValidationRuleCode, dvr.SeverityLevel,
dvr.ValidationTier, dvr.RuleID,dvo.BusinessKeyValue, dvo.ValidationMessage, dvr.IsEnabled
from dbo.DataValidationOutput dvo
inner join dbo.DataValidationRule dvr
on dvo.RuleID = dvr.RuleID
inner join dbo.DataValidationEntityList list
on dvr.EntityID = list.EntityID
where dvo.BatchID =
(
	select max(BatchID)
	from dbo.DataValidationBatch
	where RulesetCode = 'DemoRuleset' 
	and [Status] = 'S'
)
and dvr.RulesetCode = 'DemoRuleset'
and list.SchemaName = 'stg'
and list.TableName = 'Customer'
order by dvo.BusinessKeyValue, dvr.RuleID

GO
