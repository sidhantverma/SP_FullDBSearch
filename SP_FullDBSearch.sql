IF OBJECT_ID('SP_FullDBSearch') IS NOT NULL
DROP PROCEDURE SP_FullDBSearch
GO

CREATE PROCEDURE SP_FullDBSearch
(
	@search_exp NVARCHAR(100)
)
AS
BEGIN
	SET NOCOUNT ON

	IF LTRIM(RTRIM(@search_exp)) = ''
	BEGIN
		RAISERROR(N'invalid value for argument @search_exp',16,1)
		RETURN
	END

	DECLARE @Results TABLE(TableName NVARCHAR(128), ColumnName NVARCHAR(128),ColumnValue NVARCHAR(MAX))
	DECLARE @TableName			NVARCHAR(256) = '', 
			@ColumnName			NVARCHAR(128), 
			@ColumnNameList		NVARCHAR(MAX), 
			@search_exp_quoted NVARCHAR(110) = QUOTENAME(@search_exp,''''), 
			@IsFound			BIT

	WHILE @TableName IS NOT NULL
	BEGIN
		SET @IsFound = 0
		SET @ColumnName = ''
		SET @ColumnNameList = ''
		SET @TableName = 
		(
			SELECT 
				MIN(QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME))
			FROM 
				INFORMATION_SCHEMA.TABLES
			WHERE
				TABLE_TYPE = 'BASE TABLE'
				AND QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME) > @TableName
				AND OBJECTPROPERTY(OBJECT_ID(QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME)), 'IsMSShipped') = 0
		)
		WHILE (@TableName IS NOT NULL) AND (@ColumnName IS NOT NULL)
		BEGIN
			SET @ColumnName =
			(
				SELECT
					MIN(QUOTENAME(COLUMN_NAME))
				FROM 
					INFORMATION_SCHEMA.COLUMNS
				WHERE
					TABLE_SCHEMA = PARSENAME(@TableName, 2)
					AND TABLE_NAME  = PARSENAME(@TableName, 1)
					AND DATA_TYPE IN ('char', 'varchar', 'nchar', 'nvarchar', 'ntext')
					AND QUOTENAME(COLUMN_NAME) > @ColumnName
			)
			IF @ColumnName IS NOT NULL
			BEGIN
				INSERT INTO @Results
				EXEC
				(
					'SELECT ''' + @TableName + ''',''' + @TableName + '.' + @ColumnName + ''', ' + @ColumnName + '
					FROM ' + @TableName + ' (NOLOCK) ' +
					' WHERE ' + @ColumnName + ' LIKE ' + @search_exp_quoted
				)
				IF @@ROWCOUNT <> 0
				BEGIN
					SET @IsFound = 1
					SET @ColumnNameList = @ColumnName + ',' + @ColumnNameList
				END
			END
		END 
		IF @IsFound = 0
			PRINT 'Searching In... ' + @TableName
		ELSE
		BEGIN
			PRINT ''
			PRINT 'Searching In... ' + @TableName
			PRINT 'Found In ' + STUFF(@ColumnNameList, LEN(@ColumnNameList), 1, '')
			PRINT ''
		END
		
	END
	SELECT TableName, ColumnName, ColumnValue FROM @Results
END