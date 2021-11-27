SELECT 1 as BatchID, 'stg' as schemaName, 'Customer' as TableName,
( 
SELECT AffectedRow.*, 
( 
	SELECT DISTINCT dvo.RuleID as RuleID, dvr.ValidationRuleCode as ValidationRuleCode,  
	dvr.SeverityLevel as SeverityLevel, dvr.ValidationTier as ValidationTier, 
	dvr.RulesetCode as RulesetCode, 
	dvo.ValidationMessage as ValidationMessage 
	FROM dbo.DataValidationOutput dvo /* N.B: The alias must be "dvo". Read the note in the header section of this stored procedure */ 
	INNER JOIN dbo.DataValidationRule dvr 
	ON dvo.RuleID = dvr.RuleID 
	/* Explicitly convert numeric data types to nvarchar, just in case the referenced column in staging table wasnot string*/
	WHERE convert(nvarchar(200),AffectedRow.[CustomerID]) = dvo.BusinessKeyValue
	AND dvo.BatchID = AffectedRow.BatchID 
	ORDER BY dvr.ValidationTier, dvo.RuleID 
	FOR XML RAW, ROOT('BrokenRules'),TYPE 
)
FROM 
( 
	SELECT  cast(NULL as varchar(10)) as IsBusinessKeyNull, 
	dvo.BusinessKeyValue as BusinessKeyValue, 
	stg.*, 
	dvo.BatchID 
	FROM stg.Customer as stg 
	INNER JOIN 
	( 
		SELECT DISTINCT dvo1.BatchID, dvo1.BusinessKeyValue 
		FROM dbo.DataValidationOutput dvo1 
		WHERE dvo1.BatchID = 1
		AND dvo1.RuleID in 
		( 
			SELECT RuleID 
			FROM dbo.DataValidationEntityList list 
			INNER JOIN dbo.DataValidationRule dvr 
			ON list.EntityID = dvr.EntityID 
			WHERE list.SchemaName = 'stg'
			AND list.TableName = 'Customer'
			AND dvr.RulesetCode = 'DemoRuleset'
		)
	) dvo 
	ON convert(nvarchar(200),stg.[CustomerID]) = dvo.BusinessKeyValue

	UNION ALL 

	select 'Yes' as IsBusinessKeyNull, 
	cast(NULL as nvarchar(4000)) as BusinessKeyValue, 
	stg2.*, 
	cast(1 as int) as BatchID
	from stg.Customer as stg2 
	where ( [CustomerID] IS NULL ) /* BusinessKey NULL scenarios */ 
) AffectedRow /* AffectedRow could be due to Severity E and/or W) */  
 order by [CustomerID]
for XML Auto, Elements, ROOT('stg.Customer'), TYPE  
)

