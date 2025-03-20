DECLARE @ts decimal(18,2)

--Method  1 Max Memory case Max Memory (SQL Server ) < Physical Memory windows (GB)

--Method 2 SUM Usage Memory Clerks

--SELECT 
--	@ts=SUM(pages_kb)/(1024.*1024.)
--FROM sys.dm_os_memory_clerks

--Method 2 Retrive SQL Server Usage from dm_os_process_memory

SELECT @ts=physical_memory_in_use_kb/(1024.*1024.)
FROM sys.dm_os_process_memory WITH (NOLOCK) OPTION (RECOMPILE);

SELECT (@ts/4)*300

--	(Memory Usage by SQL Server in GB/4) * 300 ms

--	= (1.89 /4)*300 = 141.750000

SELECT cntr_value FROM sys.dm_os_performance_counters
WHERE object_name='SQLServer:Buffer Node'
AND counter_name='Page life expectancy'

SELECT cntr_value FROM sys.dm_os_performance_counters
WHERE object_name='SQLServer:Buffer Manager'
AND counter_name='Page life expectancy'

--If cntr_value < 141.750000 === Memory Pressure
