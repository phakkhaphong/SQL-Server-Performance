-- คำสั่งนี้จะรีเซ็ตสถิติการรอทั้งหมด (รวมถึง Latch Stats)
-- ใช้ด้วยความระมัดระวัง!
DBCC SQLPERF('sys.dm_os_latch_stats', CLEAR);

-- ตรวจสอบว่ามีตารางชั่วคราวนี้อยู่หรือไม่ ถ้ามีให้ลบทิ้งไปก่อน
IF OBJECT_ID('tempdb..#LatchStats_Snapshot1') IS NOT NULL
    DROP TABLE #LatchStats_Snapshot1;

-- เก็บข้อมูลสถิติ Latch ณ ปัจจุบันลงในตารางชั่วคราว
SELECT
    latch_class,
    waiting_requests_count,
    wait_time_ms,
    max_wait_time_ms,
    GETDATE() AS capture_time
INTO #LatchStats_Snapshot1
FROM sys.dm_os_latch_stats;

-- รอเป็นเวลา 5 นาที ก่อนจะเก็บข้อมูลครั้งต่อไป
WAITFOR DELAY '00:05:00';

-- เปรียบเทียบข้อมูล Snapshot ปัจจุบันกับ Snapshot แรกที่เก็บไว้
-- เพื่อหาสถิติ Latch ที่มีการรอสูงในช่วงเวลาที่กำหนด
WITH LatchStats_Snapshot2 AS (
    SELECT
        latch_class,
        waiting_requests_count,
        wait_time_ms,
        max_wait_time_ms
    FROM sys.dm_os_latch_stats
)
SELECT
    s2.latch_class,
    (s2.waiting_requests_count - s1.waiting_requests_count) AS delta_waits,
    (s2.wait_time_ms - s1.wait_time_ms) AS delta_wait_time_ms,
    -- คำนวณเวลารอโดยเฉลี่ยในช่วงเวลานั้นๆ
    CASE WHEN (s2.waiting_requests_count - s1.waiting_requests_count) > 0
        THEN (s2.wait_time_ms - s1.wait_time_ms) * 1.0 / (s2.waiting_requests_count - s1.waiting_requests_count)
        ELSE 0
    END AS avg_wait_time_ms,
    s2.max_wait_time_ms AS current_max_wait_time_ms,
    s1.capture_time AS snapshot1_time,
    GETDATE() AS snapshot2_time
FROM #LatchStats_Snapshot1 s1
INNER JOIN LatchStats_Snapshot2 s2 ON s1.latch_class = s2.latch_class
-- กรองเอาเฉพาะรายการที่มีการรอเกิดขึ้นจริงในช่วงที่วัดผล
WHERE (s2.wait_time_ms - s1.wait_time_ms) > 0
ORDER BY
    delta_wait_time_ms DESC; -- จัดลำดับตาม "เวลารอที่เพิ่มขึ้น" ซึ่งสำคัญที่สุด
