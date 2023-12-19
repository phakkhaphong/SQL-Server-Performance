--Display Active Waiting Task

SELECT * FROM sys.dm_os_waiting_tasks;

--Display Active Waiting Stats (SQL Server 2016 or Later)

SELECT * FROM sys.dm_exec_session_wait_stats;

--Display Historical Waiting Stats

SELECT * FROM sys.dm_os_wait_stats;
