USE master;
GO

--FROM Glenn
SELECT physical_memory_in_use_kb/(1024.*1024.) AS [SQL Server Memory Usage (GB)],
	   locked_page_allocations_kb/(1024.*1024.)  AS [SQL Server Locked Pages Allocation (GB)],
       large_page_allocations_kb/(1024.*1024.)  AS [SQL Server Large Pages Allocation (GB)], 
	   page_fault_count, memory_utilization_percentage, available_commit_limit_kb, 
	   process_physical_memory_low, process_virtual_memory_low
FROM sys.dm_os_process_memory WITH (NOLOCK) OPTION (RECOMPILE);


--FROM Instructor

SELECT 
	SUM(pages_kb)/(1024.*1024.) as PagesGB
FROM sys.dm_os_memory_clerks
