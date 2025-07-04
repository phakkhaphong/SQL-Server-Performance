SELECT TOP(20) 
	DB_NAME(t.[dbid]) AS [Database Name]
,	qs.total_worker_time AS [Total Worker Time]
,	qs.min_worker_time AS [Min Worker Time]
,	qs.total_worker_time/qs.execution_count AS [Avg Worker Time]
,	qs.max_worker_time AS [Max Worker Time]
,	qs.min_elapsed_time AS [Min Elapsed Time]
,	qs.total_elapsed_time/qs.execution_count AS [Avg Elapsed Time]
,	qs.max_elapsed_time AS [Max Elapsed Time]
,	qs.min_logical_reads AS [Min Logical Reads]
,	qs.total_logical_reads/qs.execution_count AS [Avg Logical Reads]
,	qs.max_logical_reads AS [Max Logical Reads]
,	qs.execution_count AS [Execution Count]
,	CASE 
		WHEN 
			CONVERT(nvarchar(max),qp.query_plan) COLLATE Latin1_General_BIN2 
			LIKE N'%<MissingIndexes>%' THEN 1 
			ELSE 0 
		END AS [Has Missing Index]
,	qs.creation_time AS [Creation Time]
,	qp.query_plan AS [Query Plan]
--,	t.text
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(plan_handle) AS t 
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp 
ORDER BY qs.total_worker_time DESC OPTION (RECOMPILE);
