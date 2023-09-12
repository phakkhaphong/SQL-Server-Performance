DROP TABLE IF EXISTS #xml;
GO

SELECT 
	ev = IIF([object_name]='checkpoint_begin','begin','end')
,	ed = CONVERT(xml, event_data)
INTO #xml
FROM sys.fn_xe_file_target_read_file('D:\XE\CheckPoint*.xel', NULL, NULL, NULL);

;WITH Events(ev,ts,db,id) AS
	(
	SELECT 
		ev
	,	ed.value(N'(event/@timestamp)[1]', N'datetime')
	,	ed.value(N'(event/data[@name="database_id"]/value)[1]', N'int')
	,	ed.value(N'(event/action[@name="attach_activity_id"]/value)[1]', N'uniqueidentifier')
	FROM #xml
	)

,EventPairs AS
	(
	SELECT 
		db, ev
	,	checkpoint_ended = ts
	,	checkpoint_began = LAG(ts, 1) OVER (PARTITION BY id, db ORDER BY ts)
	  FROM Events
	)

,Timings AS
	(
	SELECT 
		dbname = DB_NAME(db)
	,	checkpoint_began
	,	checkpoint_ended
	,	duration_milliseconds = DATEDIFF(MILLISECOND, checkpoint_began, checkpoint_ended) 
	FROM EventPairs WHERE ev = 'end' AND checkpoint_began IS NOT NULL
	)

SELECT 
	dbname
,	checkpoint_count    = COUNT(*)
,	avg_seconds         = CONVERT(decimal(18,2),AVG(1.0*duration_milliseconds)/1000)
,	max_seconds         = CONVERT(decimal(18,2),MAX(1.0*duration_milliseconds)/1000)
,	total_seconds_spent = CONVERT(decimal(18,2),SUM(1.0*duration_milliseconds)/1000)
FROM Timings
GROUP BY dbname
ORDER BY total_seconds_spent DESC;
