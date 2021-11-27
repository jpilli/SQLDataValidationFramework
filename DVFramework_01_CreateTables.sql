/*
Pre-requisite: 
	Staging_DB was already created for this demo. 
	Alternatively, change the database context to any other database of your choice.
*/
Use Staging_DB
GO

---------------------------------------------------------------------
-- 1.0 Data validation framework tables:
---------------------------------------------------------------------
drop table if exists dbo.DataValidationOutputXML;
GO

drop table if exists dbo.DataValidationOutput;
GO

drop table if exists dbo.DataValidationBatch;
GO

drop table if exists dbo.DataValidationRule;
GO

drop table if exists dbo.DataValidationBusinessKey;
GO

drop table if exists dbo.DataValidationEntityList;
GO

create table dbo.DataValidationEntityList(
	EntityID int NOT NULL,
	SchemaName nvarchar(128) NOT NULL,
	TableName nvarchar(128) NOT NULL,
	CompositeBusinessKeyDelimiter char(1) NULL,
	CONSTRAINT [pk_dbo_DataValidationEntityList] PRIMARY KEY CLUSTERED 
	(
		[EntityID] ASC
	),
	CONSTRAINT [uk_dbo_DVEntityList_SchemaName_TableName] UNIQUE NONCLUSTERED 
	(
		SchemaName ASC,
		TableName ASC
	)
)

GO

create table dbo.DataValidationBusinessKey(
	[EntityID] int NOT NULL,
	[ColumnName] nvarchar(128) NOT NULL,
	[BusinessKeyColumnOrder] int NOT NULL,
	CONSTRAINT [pk_dbo_DataValidationBusinessKey] PRIMARY KEY CLUSTERED 
	(
		[EntityID] ASC,
		[BusinessKeyColumnOrder] ASC
	),
	CONSTRAINT [uk_dbo_DVBusinessKey_EntityID_ColumnName] UNIQUE NONCLUSTERED 
	(
		[EntityID] ASC,
		[ColumnName] ASC
	),
	CONSTRAINT [fk_dbo_DVBusinessKey_DVEntityList_EntityID] FOREIGN KEY (EntityID) 
		REFERENCES dbo.DataValidationEntityList(EntityID)
)

GO

create table dbo.DataValidationRule(
	[RuleID] int NOT NULL,
	[RulesetCode] nvarchar(30) NOT NULL,
	[ValidationTier] smallint NOT NULL CONSTRAINT [df_dbo_DataValidationRule_ValidationTier]  DEFAULT (0),
	[EntityID] int NOT NULL,
	[ValidationRuleCode] nvarchar(200) NOT NULL,
	[ValidationRuleDesc] nvarchar(1000) NOT NULL,
	[SeverityLevel] char(1) NOT NULL CONSTRAINT [df_dbo_DataValidationRule_severitylevel]  DEFAULT ('E'),
	[IsEnabled] bit NOT NULL CONSTRAINT [df_dbo_DataValidationRule_isenabled]  DEFAULT (1)
	CONSTRAINT [pk_dbo_DataValidationRule] PRIMARY KEY CLUSTERED 
	(
		[RuleID] ASC
	),
	CONSTRAINT [uk_dbo_DVRule_RulesetCode_EntityID_RuleCode] UNIQUE NONCLUSTERED 
	(
		[RulesetCode] ASC,
		[EntityID] ASC,
		[ValidationRuleCode] ASC
	),
	CONSTRAINT [fk_dbo_DVRule_DVEntityList_EntityID] FOREIGN KEY (EntityID) 
		REFERENCES dbo.DataValidationEntityList(EntityID)

)

GO

create table dbo.DataValidationBatch(
	[BatchID] int NOT NULL identity(1,1),
	[RulesetCode] nvarchar(30) NOT NULL,
	[StartDate] datetime2(3) NOT NULL CONSTRAINT [df_dbo_DataValidationBatch_StartDate]  DEFAULT (getdate()),
	[EndDate] datetime2(3) NULL,
	[Status] nvarchar(1) NOT NULL,
	[StatusDescription] nvarchar(20) NOT NULL,
	CONSTRAINT [pk_dbo_DataValidationBatch] PRIMARY KEY CLUSTERED 
	(
		[BatchID] ASC
	)
)

GO
create table dbo.DataValidationOutput(
	[RowID] int IDENTITY(1,1) NOT NULL,
	[BatchID] int NOT NULL,
	[RuleID] int NOT NULL,
	[BusinessKeyValue] nvarchar(4000) NULL, /* Allow NULLs to cater for scenarios where business key itself wasn't provided */
	[ValidationMessage] nvarchar(4000) NULL,
	[CreatedDatetime] datetime2(3) NOT NULL CONSTRAINT [df_dbo_DataValidationOutput_CreatedDateTime]  DEFAULT (sysdatetime()),
	CONSTRAINT [pk_dbo_DataValidationOutput] PRIMARY KEY CLUSTERED 
	(
		[RowID] ASC
	),
	CONSTRAINT [fk_dbo_DVOutput_DVRule_RuleID] FOREIGN KEY (RuleID) 
		REFERENCES dbo.DataValidationRule(RuleID),
	CONSTRAINT [fk_dbo_DVOutput_DVBatch_BatchID] FOREIGN KEY (BatchID) 
		REFERENCES dbo.DataValidationBatch(BatchID)
)

GO

create table dbo.DataValidationOutputXML(
	[RowID] int IDENTITY(1,1) NOT NULL,
	[BatchID] int NOT NULL,
	SchemaName nvarchar(128) NOT NULL,
	TableName nvarchar(128) NOT NULL,
	XMLOutput XML NULL,
	[CreatedDatetime] datetime2(3) NOT NULL CONSTRAINT [df_dbo_DataValidationOutputXML_CreatedDateTime]  DEFAULT (sysdatetime()),
	CONSTRAINT [pk_dbo_DataValidationOutputXML] PRIMARY KEY CLUSTERED 
	(
		[RowID] ASC
	),
	CONSTRAINT [fk_dbo_DVOutputXML_DVBatch_BatchID] FOREIGN KEY (BatchID) 
		REFERENCES dbo.DataValidationBatch(BatchID)
)

GO
