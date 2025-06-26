### **ความเข้าใจเบื้องต้นเกี่ยวกับสถาปัตยกรรมของ SQL Server**

หัวใจสำคัญของการทำ Performance Tuning ใน SQL Server คือการทำความเข้าใจว่า "ข้างใน" ของ Database Engine ทำงานอย่างไร SQL Server ไม่ได้พึ่งพาระบบปฏิบัติการ Windows ในการจัดการงาน (Task) เพียงอย่างเดียว แต่มีระบบปฏิบัติการภายในตัวที่เรียกว่า **SQLOS (SQL Server Operating System)** ซึ่งถูกออกแบบมาโดยเฉพาะเพื่อจัดการทรัพยากรให้มีประสิทธิภาพสูงสุดสำหรับงานฐานข้อมูล

SQLOS ใช้โมเดลการจัดสรรงานที่เรียกว่า **Cooperative (Non-Preemptive) Scheduling** ซึ่งหมายความว่าแต่ละเธรดงาน (Worker) จะทำงานร่วมกันโดยการ "สละสิทธิ์" (Yield) การใช้งาน CPU ให้แก่เธรดอื่นด้วยความสมัครใจ แทนที่จะถูกระบบปฏิบัติการบังคับให้หยุด (Preempt) โมเดลนี้ช่วยลด Overhead และเพิ่มประสิทธิภาพในการจัดการกับ Request จำนวนมากพร้อมๆ กัน

### **ส่วนประกอบหลักของ SQLOS**

ภายใน SQLOS มีส่วนประกอบหลักที่ทำงานร่วมกันเพื่อจัดการกับทุก Request ที่เข้ามา:

- **Schedulers:** เปรียบเสมือนผู้จัดการที่ดูแล CPU แต่ละ Core โดยปกติแล้ว SQL Server จะสร้าง 1 Scheduler ต่อ 1 Logical CPU Core Scheduler มีหน้าที่ตัดสินใจว่าจะให้ Worker ตัวไหนเข้ามาทำงานบน CPU
    
- **Workers:** คือหน่วยปฏิบัติงาน เปรียบได้กับพนักงานแต่ละคนในทีม Worker 1 ตัว คือ 1 OS Thread ที่พร้อมจะทำงานตามที่ได้รับมอบหมาย
    
- **Tasks:** คือ "งาน" หรือ "คำสั่ง" ที่ได้รับมาจาก Client Request 1 Request อาจถูกแบ่งย่อยเป็นหลาย Task ได้ (โดยเฉพาะในกรณีของ Parallel Query)
    

### **การตรวจสอบ Schedulers**

เราสามารถตรวจสอบ Schedulers ทั้งหมดใน Instance ของเราได้โดยใช้ Dynamic Management View (DMV) ที่ชื่อว่า `sys.dm_os_schedulers`

```sql
-- Script นี้จะแสดงข้อมูลของ Schedulers ทั้งหมด
-- scheduler_id < 1048576 คือ schedulers ที่ใช้สำหรับ User connections
-- status บอกสถานะของ scheduler เช่น VISIBLE ONLINE (พร้อมใช้งาน)
-- current_tasks_count บอกจำนวน task ที่กำลังทำงานอยู่
-- runnable_tasks_count คือ "คิว" ของงานที่พร้อมจะทำงานแต่กำลังรอ CPU อยู่
-- ค่า runnable_tasks_count ที่สูงค้างอยู่ตลอดเวลา เป็นสัญญาณบ่งชี้ถึงภาวะ CPU Bottleneck

SELECT
    scheduler_id,
    cpu_id,
    status,
    current_tasks_count,
    runnable_tasks_count,
    work_queue_count,
    load_factor
FROM sys.dm_os_schedulers
WHERE scheduler_id < 1048576;
```

### **สถานะของ Worker และ Yield Mechanism (Markdown)**

หัวใจของ Cooperative Scheduling คือการที่ Worker แต่ละตัวสามารถเปลี่ยนสถานะของตัวเองได้ 3 สถานะหลักๆ ดังนี้:

1. **RUNNING:** Worker กำลังทำงานอยู่บน CPU จริงๆ
    
2. **RUNNABLE:** Worker พร้อมที่จะทำงาน แต่กำลังรอคิวเพื่อใช้งาน CPU อยู่ใน "Runnable Queue"
    
3. **SUSPENDED:** Worker ไม่สามารถทำงานต่อได้ เพราะกำลังรอทรัพยากรบางอย่างที่ยังไม่พร้อมใช้งาน จึงต้องหยุดรออยู่ใน "Waiter List"
    

การเปลี่ยนสถานะจาก `RUNNING` ไปเป็นสถานะอื่น คือกลไกที่เรียกว่า **Yield Mechanism** ซึ่งเกิดขึ้นได้จาก 2 สาเหตุหลัก

#### **ก. Voluntary Yielding (การสละสิทธิ์เมื่อครบเวลา)**

เพื่อให้เกิดความยุติธรรม SQLOS จะให้เวลาแต่ละ Worker ในการทำงานบน CPU อย่างต่อเนื่องเป็นเวลาสั้นๆ เรียกว่า **Quantum** ซึ่งมีค่าเท่ากับ **4 มิลลิวินาที**

เมื่อ Worker ทำงานครบ 4ms มันจะสละสิทธิ์ (Yield) การใช้งาน CPU ด้วยความสมัครใจ แล้วเปลี่ยนสถานะตัวเองจาก `RUNNING` ไปเป็น `RUNNABLE` เพื่อเข้าคิวรอใช้ CPU ใหม่อีกครั้ง การ Yield ในลักษณะนี้จะถูกบันทึกเป็น Wait Type **`SOS_SCHEDULER_YIELD`** การเห็น Wait Type นี้สูงๆ จึงเป็นสัญญาณบ่งชี้ถึง **CPU Pressure** หรือภาวะที่ CPU ทำงานหนักมากจนคิวยาว

#### **ข. Resource Waits (การสละสิทธิ์เพื่อรอทรัพยากร)**

นี่คือการ Yield ที่พบบ่อยที่สุด Worker ที่กำลังทำงาน (RUNNING) อาจต้องการทรัพยากรบางอย่างที่ยังไม่พร้อมใช้งาน เช่น:

- รอการอ่านข้อมูลจากดิสก์ (I/O Wait)
    
- รอการปลด Lock จาก Transaction อื่น
    
- รอ Latch เพื่อเข้าถึงโครงสร้างข้อมูลใน Memory
    

เมื่อเกิดเหตุการณ์นี้ Worker จะเปลี่ยนสถานะจาก `RUNNING` ไปเป็น `SUSPENDED` และเข้าไปรอใน "Waiter List" พร้อมบันทึก Wait Type ตามสิ่งที่มันกำลังรออยู่ เช่น **`PAGEIOLATCH_*`** (รอ I/O), **`LCK_M_*`** (รอ Lock)

### **DMVs สำหรับการตรวจสอบสถานะของ Request**

เราสามารถตรวจสอบสถานะและสิ่งที่แต่ละ Request กำลังทำหรือกำลังรออยู่ได้แบบ Real-time ผ่าน DMVs เหล่านี้:

- `sys.dm_exec_requests`: แสดงข้อมูลของ Request ที่กำลัง Active อยู่ในปัจจุบัน บอกสถานะ (running, suspended, runnable), wait type, blocking session id และอื่นๆ
    
- `sys.dm_os_tasks`: แสดง Task ทั้งหมดที่ผูกอยู่กับ Request (ในกรณีของ Parallelism จะเห็นหลาย Task ต่อ 1 Request)
    
- `sys.dm_os_waiting_tasks`: แสดงรายละเอียดของ Task ที่กำลังรออยู่ใน Waiter List (สถานะ SUSPENDED) บอกว่ากำลังรออะไร และใครเป็นคนทำให้ต้องรอ (Blocking)
    

### **Script สำหรับตรวจสอบ Request ที่กำลังทำงาน**

Script ต่อไปนี้เป็นการรวมข้อมูลจาก DMVs ที่สำคัญเพื่อให้เห็นภาพรวมของ Request ที่กำลังทำงานอยู่ในปัจจุบัน

```sql
-- Script นี้จะแสดง Request ที่กำลังทำงานอยู่ทั้งหมด (ยกเว้น System Process)
-- โดยจะบอกสถานะ, คำสั่งที่รัน, เวลาที่รอ, ประเภทการรอ และ Session ที่ทำการ Block
SELECT
    r.session_id,
    s.status AS session_status,
    r.status AS request_status,
    r.command,
    wt.wait_type,
    r.wait_time AS wait_time_ms,
    r.blocking_session_id,
    DB_NAME(r.database_id) AS database_name,
    t.text AS sql_text
FROM sys.dm_exec_requests AS r
JOIN sys.dm_exec_sessions AS s
    ON r.session_id = s.session_id
LEFT JOIN sys.dm_os_waiting_tasks AS wt
    ON r.session_id = wt.session_id
    AND r.request_id = wt.request_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE s.is_user_process = 1
AND r.session_id <> @@SPID; -- ไม่แสดง session ของตัวเอง
```

### **Workshop - จำลองสถานการณ์ Blocking**

เพื่อให้เห็นภาพการทำงานของสถานะ `SUSPENDED` เราจะมาจำลองสถานการณ์ที่เกิดการ Blocking ขึ้น ซึ่งเป็นสาเหตุหลักอย่างหนึ่งที่ทำให้ Worker ต้องเข้าสู่ Waiter List

**สถานการณ์:**

- **Session 1:** เริ่มต้น Transaction และทำการ UPDATE ข้อมูลในตาราง แต่ยังไม่ COMMIT ทำให้เกิดการ Lock ข้อมูลแถวนั้นไว้
    
- **Session 2:** พยายาม `SELECT` ข้อมูลแถวเดียวกับที่ Session 1 ทำการ Lock ไว้
    
- **Session 3:** ใช้ Script จาก Cell 6 เพื่อตรวจสอบสถานะ
    

**ผลที่คาดว่าจะได้รับ:** เราจะเห็น `session_id` ของ Session 2 อยู่ในสถานะ `SUSPENDED` และมี `wait_type` เป็น `LCK_M_S` (รอ Shared Lock) โดยมี `blocking_session_id` เป็น `session_id` ของ Session 1

### **Cell 8: Workshop - Step 1: สร้างตารางทดสอบ**

```sql
-- สร้างตารางสำหรับทดสอบ
USE tempdb;
GO

IF OBJECT_ID('dbo.LockTest', 'U') IS NOT NULL
    DROP TABLE dbo.LockTest;
GO

CREATE TABLE dbo.LockTest (
    ID INT PRIMARY KEY,
    Data VARCHAR(100)
);

INSERT INTO dbo.LockTest (ID, Data) VALUES (1, 'Initial Data');
GO
```

### **Cell 9: Workshop - Step 2: Session 1 - สร้าง Lock**

_เปิดหน้าต่าง Query ใหม่ แล้วรัน Script นี้_

```sql
-- Session 1: เริ่ม Transaction และทำการ Lock แถวข้อมูล
USE tempdb;
GO

BEGIN TRANSACTION;

UPDATE dbo.LockTest
SET Data = 'Updated by Session 1'
WHERE ID = 1;

-- สังเกตว่าเรายังไม่ COMMIT หรือ ROLLBACK
-- สามารถตรวจสอบ session_id ของหน้าต่างนี้ได้ด้วย SELECT @@SPID;
```

### **Workshop - Step 3: Session 2 - ถูก Block**

_เปิดหน้าต่าง Query ใหม่อีกหน้าต่าง แล้วรัน Script นี้_

```sql
-- Session 2: พยายามอ่านข้อมูลที่ถูก Lock
USE tempdb;
GO

SELECT * FROM dbo.LockTest WHERE ID = 1;

-- Query นี้จะค้างอยู่และไม่คืนผลลัพธ์
-- สามารถตรวจสอบ session_id ของหน้าต่างนี้ได้ด้วย SELECT @@SPID;
```

### **Workshop - Step 4: Session 3 - วิเคราะห์สถานการณ์**

_เปิดหน้าต่าง Query ใหม่อีกหน้าต่าง แล้วรัน Script จาก Cell 6 เพื่อวิเคราะห์_

```sql
-- Session 3: ใช้ Script วิเคราะห์สถานการณ์
-- คุณจะเห็นว่า Session 2 (จากขั้นตอนที่แล้ว) อยู่ในสถานะ SUSPENDED
SELECT
    r.session_id,
    s.status AS session_status,
    r.status AS request_status,
    r.command,
    wt.wait_type,
    r.wait_time AS wait_time_ms,
    r.blocking_session_id,
    DB_NAME(r.database_id) AS database_name,
    t.text AS sql_text
FROM sys.dm_exec_requests AS r
JOIN sys.dm_exec_sessions AS s
    ON r.session_id = s.session_id
LEFT JOIN sys.dm_os_waiting_tasks AS wt
    ON r.session_id = wt.session_id
    AND r.request_id = wt.request_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE s.is_user_process = 1
AND r.session_id <> @@SPID;
```

### **Workshop - Step 5: Cleanup**

_กลับไปที่หน้าต่างของ Session 1 แล้วรัน Script นี้เพื่อปลด Lock และลบตาราง_

```sql
-- Session 1: ทำการ ROLLBACK เพื่อปลด Lock
ROLLBACK TRANSACTION;
GO

-- Cleanup
USE tempdb;
DROP TABLE dbo.LockTest;
GO
```

### **สรุป**

จากบทเรียนและ Workshop นี้ เราได้เห็นกลไกการทำงานของ **SQL Server Execution Model** อย่างละเอียด จะเห็นได้ว่าการที่ SQL Server สามารถจัดการ Request จำนวนมากได้นั้น เกิดจากการออกแบบของ SQLOS ที่ให้แต่ละ Worker ทำงานร่วมกันผ่าน **Yield Mechanism** การเข้าใจสถานะ `RUNNING`, `RUNNABLE`, `SUSPENDED` และการวิเคราะห์ **Wait Statistics** คือกุญแจสำคัญในการวินิจฉัยปัญหา узловой (bottleneck) และปรับปรุงประสิทธิภาพของระบบฐานข้อมูลของเราได้อย่างตรงจุด ไม่ว่าปัญหานั้นจะเกิดจาก CPU, I/O, หรือการแย่งชิงทรัพยากร (Contention) ก็ตาม
