-- ขั้นตอนที่ 1 - เปิดและรัน 
-- จดบันทึกค่าของ update_session_id ในบานหน้าต่างผลลัพธ์

-- ขั้นตอนที่ 2 - จากโซลูชันเปิดและเรียกใช้แบบสอบถาม Demo2ii - เริ่มบล็อก transaction.sql กับ MIA-SQL
-- จดบันทึกค่าของ select_session_id ในบานหน้าต่างผลลัพธ์

-- ขั้นตอนที่ 3 - เพิ่มค่าของ update_session_id และ select_session_id ที่รวบรวมในสองขั้นตอนสุดท้าย
-- ไปที่โต๊ะชั่วคราว
- แทนที่ค่าในส่วนคําสั่ง VALUES ด้านล่าง (คุณสามารถใช้พารามิเตอร์เทมเพลต - Ctrl + Shift + M)
DROP TABLE IF EXISTS #session;
CREATE TABLE #session (session_id int NOT NULL);

INSERT #session
VALUES (<update_session_id, int,NULL>),(<select_session_id, int, NULL>);


-- Step 4 - View session status 
-- Note that:
--   the update session has the status sleeping
--   the select session has the status running
SELECT status, * 
FROM sys.dm_exec_sessions 
WHERE session_id IN (SELECT session_id FROM #session);

-- Step 5 - View request status
-- Note that:
--   the update session has no request, because it is not currently working
--   the select session request has a suspended status, because it is waiting for a resource to become free
SELECT status, * 
FROM sys.dm_exec_requests  
WHERE session_id IN (SELECT session_id FROM #session);

-- Step 6 - View task status
--   the update session has no task, because it is not currently working
--   the select session task has a suspended status, because it is waiting for a resource to become free
SELECT * 
FROM sys.dm_os_tasks
WHERE session_id IN (SELECT session_id FROM #session);

-- Step 7 - View worker status
--   the update session has no worker, because it is not currently working
--   the select session worker has a suspended status, because it is waiting for a resource to become free
SELECT dot.session_id, dow.state, dow.*
FROM sys.dm_os_workers AS dow
JOIN sys.dm_os_tasks AS dot
ON   dot.task_address = dow.task_address
WHERE dot.session_id IN (SELECT session_id FROM #session);

-- Step 8 - view time spent waiting/runnable
SELECT	dot.session_id, 
		dow.state,
		CASE WHEN dow.state = 'SUSPENDED' 
			 THEN (SELECT ms_ticks FROM sys.dm_os_sys_info) - dow.wait_started_ms_ticks
			 ELSE NULL
		END AS time_spent_waiting_ms,
		CASE WHEN dow.state = 'RUNNABLE' 
			 THEN (SELECT ms_ticks FROM sys.dm_os_sys_info) - dow.wait_resumed_ms_ticks
			 ELSE NULL
		END AS time_spent_runnable_ms
FROM sys.dm_os_workers AS dow
JOIN sys.dm_os_tasks AS dot
ON   dot.task_address = dow.task_address
WHERE dot.session_id IN (SELECT session_id FROM #session);

-- Step 9 - view thread status
--   the update session has no thread, because it is not currently working
--   the select session thread has a suspended status, because it is waiting for a resource to become free
SELECT dot.session_id,  dth.*
FROM sys.dm_os_threads dth
JOIN sys.dm_os_workers AS dow
ON	 dow.worker_address = dth.worker_address
JOIN sys.dm_os_tasks AS dot
ON   dot.task_address = dow.task_address
WHERE dot.session_id IN (SELECT session_id FROM #session);

-- Step 10 - return to the query window where Demo2i - Create hanging transaction.sql is running.
-- Uncomment and execute the ROLLBACK command at the end of the file

-- Step 11 - return to the query window where Demo2ii - Start blocked transaction.sql is running.
-- notice that the query is no longer blocked and results have been returned.
