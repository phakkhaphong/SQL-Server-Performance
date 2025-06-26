-- ขั้นตอนที่ 1 - เปิดและรัน 05.Session01.Create-Hanging-Transaction.sql
-- จดบันทึกค่าของ update_session_id ในบานหน้าต่างผลลัพธ์

-- ขั้นตอนที่ 2 - เปิดและรัน 05.Session02.Start-blocked-transaction.sql
-- จดบันทึกค่าของ select_session_id ในบานหน้าต่างผลลัพธ์

-- ขั้นตอนที่ 3 - เพิ่มค่าของ update_session_id และ select_session_id ที่รวบรวมในสองขั้นตอนแรก
-- ไปที่ temporary table

-- แทนที่ค่าในส่วนคําสั่ง VALUES ด้านล่าง (คุณสามารถใช้พารามิเตอร์เทมเพลต - Ctrl + Shift + M)

DROP TABLE IF EXISTS #session;
CREATE TABLE #session (session_id int NOT NULL);

INSERT #session
VALUES (63),(99);

SELECT * FROM #session


-- ขั้นตอนที่ 4 - ดูสถานะ session
-- โปรดทราบว่า:
-- update session มีสถานะ Sleeping
-- select session มีสถานะ Running

SELECT status, * 
FROM sys.dm_exec_sessions 
WHERE session_id IN (SELECT session_id FROM #session);

-- ขั้นตอนที่ 5 - ดูสถานะ request
-- โปรดทราบว่า:
-- update session ไม่มีคําขอ เนื่องจากไม่ทํางานในขณะนี้
-- คําขอของ select session มีสถานะ suspended  เนื่องจากกําลังรอให้ทรัพยากรว่าง

SELECT status, * 
FROM sys.dm_exec_requests  
WHERE session_id IN (SELECT session_id FROM #session);

SELECT
*
FROM sys.dm_os_waiting_tasks
WHERE session_id IN (SELECT session_id FROM #session);

-- ขั้นตอนที่ 6 - ดูสถานะ task
-- update session ไม่มีงาน เนื่องจากไม่ทํางานในขณะนี้
-- งานของ select session มีสถานะ suspended เนื่องจากกําลังรอให้ทรัพยากรว่าง

SELECT * 
FROM sys.dm_os_tasks
WHERE session_id IN (SELECT session_id FROM #session);

-- ขั้นตอนที่ 7 - ดูสถานะ Worker
-- update session ไม่มี Worker เนื่องจากไม่ได้ทํางานอยู่ในขณะนี้
-- Worker ของ select session มีสถานะ suspended เนื่องจากกําลังรอให้ทรัพยากรว่าง

SELECT dot.session_id, dow.state, dow.*
FROM sys.dm_os_workers AS dow
JOIN sys.dm_os_tasks AS dot
ON   dot.task_address = dow.task_address
WHERE dot.session_id IN (SELECT session_id FROM #session);

-- ขั้นตอนที่ 8 - ดูเวลาที่ใช้ใน waiting/runnable
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

-- ขั้นตอนที่ 9 - ดูสถานะ thread
-- update session ไม่มีเธรดเนื่องจากไม่ทํางาน
-- เธรดของ select session มีสถานะ suspended เนื่องจากกําลังรอให้ทรัพยากรว่าง

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

-- ขั้นตอนที่ 10 - กลับไปที่ 05.Session01.Create-Hanging-Transaction.sql ที่กำลังทำงานอยู่
-- ยกเลิกด้วยคําสั่ง ROLLBACK ที่ส่วนท้ายของไฟล์

-- ขั้นตอนที่ 11 - กลับไปที่ 05.Session02.Start-blocked-transaction.sql
-- สังเกตว่า Query ไม่ได้ถูกบล็อกอีกต่อไปและผลลัพธ์ถูกส่งคืนแล้ว
