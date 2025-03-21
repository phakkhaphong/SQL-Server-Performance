SELECT 
	DB_NAME(fs.database_id) AS [Database Name]
,	CAST(fs.io_stall_read_ms/(1.0 + fs.num_of_reads) AS NUMERIC(10,1)) AS [avg_read_latency_ms]
,	CAST(fs.io_stall_write_ms/(1.0 + fs.num_of_writes) AS NUMERIC(10,1)) AS [avg_write_latency_ms]
,	CAST((fs.io_stall_read_ms + fs.io_stall_write_ms)/(1.0 + fs.num_of_reads + fs.num_of_writes) AS NUMERIC(10,1)) AS [avg_io_latency_ms]
,	CONVERT(DECIMAL(18,2), mf.size/128.0) AS [File Size (MB)]
,	mf.physical_name
,	mf.type_desc
,	fs.io_stall_read_ms
,	fs.num_of_reads
,	fs.io_stall_write_ms
,	fs.num_of_writes
,	fs.io_stall_read_ms + fs.io_stall_write_ms AS [io_stalls]
,	fs.num_of_reads + fs.num_of_writes AS [total_io]
,	io_stall_queued_read_ms AS [Resource Governor Total Read IO Latency (ms)]
,	io_stall_queued_write_ms AS [Resource Governor Total Write IO Latency (ms)] 
FROM sys.dm_io_virtual_file_stats(null,null) AS fs
INNER JOIN sys.master_files AS mf WITH (NOLOCK)
ON fs.database_id = mf.database_id
AND fs.[file_id] = mf.[file_id]
ORDER BY avg_io_latency_ms DESC OPTION (RECOMPILE);
