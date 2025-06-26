-- ตรวจสอบว่ามีตารางชั่วคราวนี้อยู่หรือไม่ ถ้ามีให้ลบทิ้งไปก่อน
IF OBJECT_ID('tempdb..#SpinlockStats_Snapshot1') IS NOT NULL
    DROP TABLE #SpinlockStats_Snapshot1;

-- เก็บข้อมูลสถิติ Spinlock ณ ปัจจุบันลงในตารางชั่วคราว
SELECT
    name,
    collisions,
    spins,
    spins_per_collision,
    sleep_time,
    backoffs,
    GETDATE() AS capture_time
INTO #SpinlockStats_Snapshot1
FROM sys.dm_os_spinlock_stats;

-- รอเป็นเวลา 5 นาที ก่อนจะเก็บข้อมูลครั้งต่อไป
WAITFOR DELAY '00:05:00';

-- เปรียบเทียบข้อมูล Snapshot ปัจจุบันกับ Snapshot แรกที่เก็บไว้
-- เพื่อหาสถิติที่เปลี่ยนแปลงไปในช่วงเวลาที่กำหนด
WITH SpinlockStats_Snapshot2 AS (
    SELECT
        name,
        collisions,
        spins,
        spins_per_collision,
        sleep_time,
        backoffs
    FROM sys.dm_os_spinlock_stats
)
SELECT
    s2.name AS spinlock_name,
    (s2.collisions - s1.collisions) AS delta_collisions,
    (s2.spins - s1.spins) AS delta_spins,
    (s2.sleep_time - s1.sleep_time) AS delta_sleep_time_ms,
    (s2.backoffs - s1.backoffs) AS delta_backoffs,
    s1.capture_time AS snapshot1_time,
    GETDATE() AS snapshot2_time
FROM #SpinlockStats_Snapshot1 s1
INNER JOIN SpinlockStats_Snapshot2 s2 ON s1.name = s2.name
-- กรองเอาเฉพาะรายการที่มีการเปลี่ยนแปลงเพื่อลด Noise
WHERE (s2.collisions - s1.collisions) > 0
ORDER BY
    delta_backoffs DESC,          -- จัดลำดับตาม Backoffs ที่เพิ่มขึ้น (สำคัญที่สุด)
    delta_collisions DESC,        -- ตามด้วย Collisions
    delta_spins DESC;             -- และ Spins
