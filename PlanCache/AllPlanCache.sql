SELECT 
	cp.*
,	X.query_plan
FROM sys.dm_exec_cached_plans as cp
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle)as X
