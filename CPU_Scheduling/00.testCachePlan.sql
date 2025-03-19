USE Master;
GO

SELECT * FROM sys.dm_exec_cached_plans as cp


SELECT * FROM sys.dm_exec_query_plan(--HashCode Plan Handle---)
GO

SELECT 
	cp.*
,	X.query_plan
FROM sys.dm_exec_cached_plans as cp
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) as X
GO

SELECT rq.* FROM sys.dm_exec_requests as rq
INNER JOIN sys.dm_exec_sessions as ss ON rq.session_id=ss.session_id
WHERE ss.is_user_process=1

SELECT * FROM sys.dm_exec_sql_text(--sql-handle---)

SELECT * FROM sys.dm_exec_query_plan(--Plan-handle--)

GO

SELECT 
	cp.*
,	X.text
,	Y.query_plan
FROM sys.dm_exec_cached_plans as cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) as X
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) as Y;
