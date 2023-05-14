CREATE EVENT SESSION [CheckpointTracking] ON SERVER 
ADD EVENT sqlserver.checkpoint_begin(
    WHERE ([sqlserver].[database_name]=N'master' OR [sqlserver].[database_name]=N'tempdb' OR [sqlserver].[database_name]=N'msdb')),
ADD EVENT sqlserver.checkpoint_end(
    WHERE ([sqlserver].[database_name]=N'master' OR [sqlserver].[database_name]=N'tempdb' OR [sqlserver].[database_name]=N'msdb'))
ADD TARGET package0.event_file(SET filename=N'D:\XE\CheckPointTracking.xel',max_file_size=(128),max_rollover_files=(50))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
GO


