-- CPU Scheduling - Monitor Engine

-- Step 1 เปิด Workload
-- ผู้สอนเปิด Workload ที่สร้างโดยสคริปต์จะใช้เวลาประมาณ 5 นาที 

-- ขั้นตอนที่ 2 - แสดง Sessions
-- โปรดทราบว่า Query นี้ ส่งคืนรายละเอียดของเซสชันผู้ใช้แต่ละเซสชัน รวมถึงชื่อโปรแกรมไคลเอ็นต์ 
-- ข้อมูลที่เกี่ยวข้องกับความปลอดภัย และสถานะของเซสชัน 

SELECT * FROM sys.dm_exec_sessions 
ORDER BY session_id DESC;

-- ขั้นตอนที่ 3 - แสดง Request
-- โปรดทราบว่า Query นี้ นี้ส่งคืนแถวข้อมูลสําหรับแต่ละคําขอที่ใช้งานอยู่ รวมถึงสถานะ 
-- คอลัมน์ที่แสดงว่าคําขอกําลังทํางาน รันได้ หรือถูกระงับ

SELECT * FROM sys.dm_exec_requests;

SELECT * FROM sys.dm_exec_requests as rq
INNER JOIN sys.dm_exec_sessions as ss ON rq.session_id=ss.session_id
WHERE ss.is_user_process=1

-- ขั้นตอนที่ 4 - แสดง Tasks
-- โปรดทราบว่า Query นี้ นี้ส่งคืนแถวข้อมูลสําหรับแต่ละงานที่ใช้งานอยู่ 
-- คอลัมน์ task_state แสดงว่า  RUNNING, SUSPENDED หรือ RUNNABLE
	
SELECT * from sys.dm_os_tasks;

SELECT * from sys.dm_os_tasks as ts 
INNER JOIN sys.dm_exec_sessions as ss ON ts.session_id=ss.session_id
WHERE ss.is_user_process=1;

-- ขั้นตอนที่ 5 - แสดง schedulers
-- โปรดทราบว่าคอลัมน์ current_tasks_count และ runnable_tasks_count ระบุจํานวน tasks  
-- และ runnable tasks ทั้งหมด ในกลไก scheduler  
-- runnable tasks ที่ใช้เวลานานมีจํานวนมาก อาจบ่งบอกถึง CPU pressure

SELECT * FROM sys.dm_os_schedulers;

SELECT * FROM sys.dm_os_schedulers
WHERE status='VISIBLE ONLINE';

-- ขั้นตอนที่ 6 แสดงข้อมูลทั้งหมดรวมกัน

SELECT * 
FROM sys.dm_exec_sessions AS ses
JOIN sys.dm_exec_requests AS req
ON   req.session_id = ses.session_id
JOIN sys.dm_os_tasks AS tsk
ON   tsk.session_id = ses.session_id
JOIN sys.dm_os_schedulers AS sch
ON	 sch.scheduler_id = tsk.scheduler_id
WHERE ses.is_user_process =1;

-- ขั้นตอนที่ 7 ประวัติ CPU จาก sys.dm_os_ring_buffer

SELECT Notification_Time, ProcessUtilization AS SQLProcessUtilization,
SystemIdle, 100 - SystemIdle - ProcessUtilization AS OtherProcessUtilization
FROM (	SELECT	r.value('(./Record/@id)[1]', 'int') AS record_id,
				r.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS SystemIdle,
				r.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS ProcessUtilization,
				Notification_Time
		FROM (	SELECT	CONVERT(xml, record) as r,
						DATEADD(ms, (rbf.timestamp - tme.ms_ticks), 
						GETDATE()) as Notification_Time
				FROM sys.dm_os_ring_buffers AS rbf
				CROSS join sys.dm_os_sys_info tme
				WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
			) AS x
	) AS y
ORDER BY record_id DESC
