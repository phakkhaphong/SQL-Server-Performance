SELECT 
	CONVERT(decimal(18,2), migs.user_seeks * migs.avg_total_user_cost * (migs.avg_user_impact * 0.01)) AS [index_advantage]
,	CONVERT(nvarchar(25), migs.last_user_seek, 20) AS [last_user_seek]
,	mid.[statement] AS [Database.Schema.Table]
,	COUNT(1) OVER(PARTITION BY mid.[statement]) AS [missing_indexes_for_table]
,	COUNT(1) OVER(PARTITION BY mid.[statement], mid.equality_columns) AS [similar_missing_indexes_for_table]
,	mid.equality_columns, mid.inequality_columns, mid.included_columns, migs.user_seeks
,	CONVERT(decimal(18,2), migs.avg_total_user_cost) AS [avg_total_user_,cost]
,	migs.avg_user_impact
,	REPLACE(REPLACE(LEFT(st.[text], 255), CHAR(10),''), CHAR(13),'') AS [Short Query Text]
FROM sys.dm_db_missing_index_groups AS mig WITH (NOLOCK) 
INNER JOIN sys.dm_db_missing_index_group_stats_query AS migs WITH(NOLOCK) 
ON mig.index_group_handle = migs.group_handle 
CROSS APPLY sys.dm_exec_sql_text(migs.last_sql_handle) AS st 
INNER JOIN sys.dm_db_missing_index_details AS mid WITH (NOLOCK) 
ON mig.index_handle = mid.index_handle 
ORDER BY index_advantage DESC OPTION (RECOMPILE);
