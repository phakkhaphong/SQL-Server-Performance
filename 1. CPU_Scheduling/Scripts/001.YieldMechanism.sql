SELECT 
	scheduler_id
,	cpu_id
,	current_tasks_count
,	runnable_tasks_count
,	work_queue_count
,	yield_count					-- จำนวนครั้งที่ Worker Thread Yield CPU
,	last_timer_activity			-- Timestamp การ Yield ล่าสุด
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255		-- เฉพาะ Scheduler ที่ใช้สำหรับ Query Processing
