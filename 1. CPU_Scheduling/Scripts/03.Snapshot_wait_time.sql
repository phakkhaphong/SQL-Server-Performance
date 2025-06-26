SELECT 
	* 
,	wait_time_ms-signal_wait_time_ms as resource_wait_time_ms
INTO #DeltaWait
FROM sys.dm_os_wait_stats

WAITFOR DELAY '00:00:30'

SELECT 
	CW.wait_type
,	CW.wait_time_ms-DW.wait_time_ms as wait_time_ms
,	CW.signal_wait_time_ms-DW.signal_wait_time_ms as signal_wait_time_ms
,	(CW.wait_time_ms-CW.signal_wait_time_ms)-DW.resource_wait_time_ms as resource_wait_time_ms
FROM sys.dm_os_wait_stats as CW INNER JOIN #DeltaWait as DW
ON CW.wait_type=DW.wait_type
ORDER BY wait_time_ms DESC
