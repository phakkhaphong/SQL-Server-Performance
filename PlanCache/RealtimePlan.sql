SELECT TOP 10
--	rq.*
	x.query_plan
,   Y.text
FROM sys.dm_exec_requests as rq 
CROSS APPLY sys.dm_exec_query_plan(rq.plan_handle)as X
CROSS APPLY sys.dm_exec_sql_text(rq.plan_handle)as Y
ORDER BY rq.total_elapsed_time DESC
