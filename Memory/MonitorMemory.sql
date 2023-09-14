USE master;
GO

--FROM Microsoft
select
physical_memory_in_use_kb,
locked_page_allocations_kb,
total_virtual_address_space_kb,
virtual_address_space_committed_kb,
process_physical_memory_low,
process_virtual_memory_low
from sys.dm_os_process_memory;
GO


  --FROM Glenn
SELECT physical_memory_in_use_kb/1024 AS [SQL Server Memory Usage (MB)],
	   locked_page_allocations_kb/1024 AS [SQL Server Locked Pages Allocation (MB)],
       large_page_allocations_kb/1024 AS [SQL Server Large Pages Allocation (MB)], 
	   page_fault_count, memory_utilization_percentage, available_commit_limit_kb, 
	   process_physical_memory_low, process_virtual_memory_low
FROM sys.dm_os_process_memory WITH (NOLOCK) OPTION (RECOMPILE);
