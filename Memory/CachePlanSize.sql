SELECT 
	objtype
,	COUNT(*) as NumberOfPlan
,	SUM(size_in_bytes)/(1024.*1024.) as SizeMB
FROM sys.dm_exec_cached_plans AS cp WITH (NOLOCK)
GROUP BY objtype
