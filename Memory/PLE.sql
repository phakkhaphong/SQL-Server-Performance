SELECT physical_memory_in_use_kb/(1024.*1024.) as MemoryUsageGB FROM sys.dm_os_process_memory
SELECT SUM(pages_kb)/(1024.*1024.) as MemoryUsageGB FROM sys.dm_os_memory_clerks

--	(Memory Usage by SQL Server in GB/4) * 300 ms

--	= (1.89 /4)*300 = 141.750000

SELECT cntr_value FROM sys.dm_os_performance_counters
WHERE object_name='SQLServer:Buffer Node'
AND counter_name='Page life expectancy'

--If cntr_value < 141.750000 === Memory Pressure
