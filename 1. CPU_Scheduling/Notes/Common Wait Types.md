# SQL Server Wait Types ที่พบบ่อย: คำอธิบายและการวิเคราะห์

เอกสารนี้จะอธิบาย Wait Types ต่างๆ ที่พบได้บ่อยใน SQL Server เพื่อช่วยให้เข้าใจถึงปัญหาคอขวด (Bottleneck) และแนวทางการแก้ไขได้อย่างมีประสิทธิภาพ

---

### **LCK_M_***

**คำอธิบาย:** `LCK_M_*` (Lock Manager) เป็นกลุ่มของ Wait Type ที่เกิดขึ้นเมื่อ Session หนึ่งกำลังรอการอนุญาตให้เข้าถึงทรัพยากร (เช่น Row, Page, Table) ที่ถูก Session อื่น Lock ไว้อยู่ในโหมดที่เข้ากันไม่ได้ (Incompatible Mode) การรอประเภทนี้เป็นสาเหตุหลักของปัญหา Blocking และอาจนำไปสู่ Deadlock ได้

**สาเหตุที่พบบ่อย:**

- **Long-running Transactions:** Transaction ที่ใช้เวลานานจะถือ Lock ไว้นาน ทำให้ Session อื่นต้องรอ
    
- **Inefficient Queries:** Query ที่มีการ Scan ข้อมูลจำนวนมาก (Table Scan/Index Scan) ทำให้เกิดการ Lock ทรัพยากรเป็นวงกว้างและนานขึ้น
    
- **Lock Escalation:** การยกระดับการ Lock จากระดับ Row หรือ Page ไปเป็นระดับ Table ทำให้เกิด Blocking เป็นวงกว้าง
    
- **Isolation Level ที่ไม่เหมาะสม:** การใช้ Isolation Level ระดับสูงเกินความจำเป็น (เช่น REPEATABLE READ, SERIALIZABLE) จะทำให้เกิดการ Lock ทรัพยากรนานขึ้น
    

**สคริปต์ประกอบการวิเคราะห์:**

1. **ตรวจสอบค่าสถิติของ Lock Waits:**
    
      
    ```sql
    -- ตรวจสอบ Wait Time สะสมของ LCK_M_* waits
    SELECT
        wait_type,
        waiting_tasks_count,
        wait_time_ms,
        max_wait_time_ms,
        signal_wait_time_ms
    FROM sys.dm_os_wait_stats
    WHERE wait_type LIKE 'LCK_M_%'
    ORDER BY wait_time_ms DESC;
    ```
    
2. **ตรวจสอบ Session ที่กำลัง Block กันอยู่:**
    
        
    ```sql
    -- ค้นหา Session ที่กำลังรอ Lock (Blocked) และ Session ที่เป็นต้นเหตุ (Blocking)
    SELECT
        db_name(r.database_id) AS DatabaseName,
        r.session_id AS WaitingSessionID,
        r.blocking_session_id AS BlockingSessionID,
        r.wait_type,
        r.wait_time AS WaitTime_ms,
        r.wait_resource,
        st.text AS WaitingSQLText,
        bst.text AS BlockingSQLText
    FROM sys.dm_exec_requests r
    OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) st
    LEFT JOIN sys.dm_exec_requests br ON r.blocking_session_id = br.session_id
    OUTER APPLY sys.dm_exec_sql_text(br.sql_handle) bst
    WHERE r.blocking_session_id <> 0;
    ```
    

---

### **PAGELATCH_***

**คำอธิบาย:** `PAGELATCH_*` เป็นการรอเพื่อเข้าถึง Data Page หรือ Index Page ที่อยู่ใน Memory (Buffer Pool) ในระยะเวลาสั้นๆ เพื่อให้มั่นใจว่าโครงสร้างของ Page มีความสมบูรณ์ในระหว่างที่มีการแก้ไข การรอนี้ไม่ใช่ปัญหา I/O แต่เป็นปัญหาที่เกิดจากการเข้าถึง Page เดียวกันพร้อมกันจำนวนมาก (Contention)

**สาเหตุที่พบบ่อย:**

- **TempDB Contention:** การสร้างและลบตารางชั่วคราว (Temporary Tables) หรือ Table Variables จำนวนมากในเวลาเดียวกัน ทำให้เกิดการแย่งกันเข้าถึง Allocation Pages (PFS, GAM, SGAM) ใน TempDB
    
- **Hot Pages:** มีการ Insert ข้อมูลพร้อมกันจำนวนมากลงใน Page สุดท้ายของตารางที่มี Clustered Index เป็นคอลัมน์ Identity (Last-page insert contention)
    

**สคริปต์ประกอบการวิเคราะห์:**


```sql
-- ตรวจสอบ Latch waits และระบุ Page ที่มีปัญหา
SELECT
    wt.session_id,
    wt.wait_duration_ms,
    wt.wait_type,
    wt.resource_description
FROM sys.dm_os_waiting_tasks AS wt
WHERE wt.wait_type LIKE 'PAGELATCH%' AND wt.session_id > 50;

-- หาก resource_description เป็น 2:x:y แสดงว่าเป็นปัญหาที่ TempDB
-- 2 คือ database_id ของ TempDB
-- x คือ file_id
-- y คือ page_id (ถ้าเป็น 1 คือ PFS, 2 คือ GAM, 3 คือ SGAM)
```

---

### **PAGEIOLATCH_***

**คำอธิบาย:** `PAGEIOLATCH_*` เกิดขึ้นเมื่อ Session ต้องรอการอ่าน Data Page หรือ Index Page จาก Disk เข้ามาใน Memory (Buffer Pool) ซึ่งบ่งชี้ถึงปัญหาคอขวดที่ระบบ I/O (I/O Bottleneck) โดยตรง

**สาเหตุที่พบบ่อย:**

- **I/O Subsystem ช้า:** Disk มีความเร็วในการอ่าน/เขียนไม่เพียงพอ
    
- **Memory ไม่เพียงพอ:** SQL Server มีหน่วยความจำไม่พอสำหรับ Buffer Pool ทำให้ต้องอ่านข้อมูลจาก Disk บ่อยครั้ง
    
- **Query ที่ไม่มีประสิทธิภาพ:** Query ที่ทำให้เกิดการอ่านข้อมูลจำนวนมากเกินความจำเป็น เช่น ขาด Index ที่เหมาะสม ทำให้เกิด Table Scan บนตารางขนาดใหญ่
    
- **สถิติไม่อัปเดต:** ทำให้ Query Optimizer เลือกแผนการทำงานที่ไม่มีประสิทธิภาพและอ่านข้อมูลจาก Disk มากเกินไป
    

**สคริปต์ประกอบการวิเคราะห์:**


```sql
-- ตรวจสอบ Latency ของไฟล์ข้อมูลแต่ละไฟล์
SELECT
    DB_NAME(vfs.database_id) AS DatabaseName,
    mf.name AS LogicalFileName,
    mf.physical_name AS PhysicalFileName,
    vfs.io_stall_read_ms,
    vfs.num_of_reads,
    CASE WHEN vfs.num_of_reads = 0 THEN 0
         ELSE vfs.io_stall_read_ms / vfs.num_of_reads
    END AS AvgReadStall_ms,
    vfs.io_stall_write_ms,
    vfs.num_of_writes,
    CASE WHEN vfs.num_of_writes = 0 THEN 0
         ELSE vfs.io_stall_write_ms / vfs.num_of_writes
    END AS AvgWriteStall_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
JOIN sys.master_files AS mf
    ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
ORDER BY AvgReadStall_ms DESC;
```

---

### **CXPACKET**

**คำอธิบาย:** `CXPACKET` เกิดขึ้นเมื่อมีการประมวลผลแบบขนาน (Parallelism) โดยเป็นสถานะที่ Thread หนึ่งทำงานของตัวเองเสร็จแล้ว และกำลังรอ Thread อื่นๆ ในกลุ่มทำงานให้เสร็จเพื่อจะนำผลลัพธ์มารวมกัน การพบ CXPACKET ไม่ได้หมายความว่ามีปัญหาเสมอไป แต่เป็นตัวบ่งชี้ว่ามีการใช้ Parallel Plan

**สาเหตุที่พบบ่อย (ที่อาจเป็นปัญหา):**

- **Uneven Workload:** ข้อมูลที่กระจายตัวไม่สม่ำเสมอ ทำให้บาง Thread ทำงานหนักและนานกว่า Thread อื่น
    
- **Cost Threshold for Parallelism ต่ำเกินไป:** ทำให้ Query ที่ไม่ซับซ้อนมากทำงานแบบขนานโดยไม่จำเป็น
    
- **Outdated Statistics:** ทำให้ Optimizer ประมาณการ Cardinality ผิดพลาด และเลือกใช้ Parallel Plan ที่ไม่มีประสิทธิภาพ
    
- **Underlying Waits:** Thread บางตัวอาจติด Wait Type อื่นๆ เช่น `PAGEIOLATCH_*` หรือ `LCK_M_*` ทำให้ทำงานช้ากว่า Thread อื่น
    

**สคริปต์ประกอบการวิเคราะห์:**


```sql
-- ตรวจสอบว่า CXPACKET มาพร้อมกับ Wait Type อื่นหรือไม่
-- โดยเปลี่ยน session_id เป็น ID ของ Session ที่มีปัญหา CXPACKET
SELECT
    task.session_id,
    task.exec_context_id,
    task.wait_type AS task_wait_type,
    req.wait_type AS request_wait_type,
    req.wait_resource,
    req.status
FROM sys.dm_os_tasks AS task
JOIN sys.dm_exec_requests AS req
    ON task.session_id = req.session_id
WHERE task.session_id = <your_session_id>
ORDER BY task.exec_context_id;
```

---

### **WRITELOG**

**คำอธิบาย:** `WRITELOG` เกิดขึ้นเมื่อ Session กำลังรอให้ SQL Server เขียนข้อมูลใน Log Buffer ลงไปในไฟล์ Transaction Log บน Disk ซึ่งมักเกิดขึ้นตอนที่มีการ `COMMIT TRANSACTION`

**สาเหตุที่พบบ่อย:**

- **Disk I/O ของ Log File ช้า:** เป็นสาเหตุที่พบบ่อยที่สุด
    
- **Chatty Transactions:** มี Transaction ขนาดเล็กจำนวนมากเกิดขึ้นในเวลาสั้นๆ ทำให้เกิดการ Flush Log Buffer บ่อยครั้ง
    
- **ขนาด Log Buffer เล็กเกินไป:** ทำให้ Buffer เต็มเร็วและต้องรอการเขียนลง Disk
    

**สคริปต์ประกอบการวิเคราะห์:**


```sql
-- ตรวจสอบ Latency ของ Transaction Log File
SELECT
    DB_NAME(vfs.database_id) AS DatabaseName,
    mf.physical_name,
    vfs.io_stall_write_ms,
    vfs.num_of_writes,
    CASE WHEN vfs.num_of_writes = 0 THEN 0
         ELSE vfs.io_stall_write_ms / vfs.num_of_writes
    END AS AvgWriteStall_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
JOIN sys.master_files mf
    ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
WHERE mf.type_desc = 'LOG'
ORDER BY AvgWriteStall_ms DESC;
```

---

### **BACKUPTHREAD**

**คำอธิบาย:** Wait Type นี้เกิดขึ้นเมื่อ Thread กำลังทำงานเกี่ยวกับการสำรองข้อมูล (Backup) การพบ Wait Type นี้เป็นเรื่องปกติระหว่างการ Backup แต่ถ้ามีค่า `wait_time_ms` สูงมาก อาจบ่งชี้ถึงปัญหาคอขวดที่ I/O ของอุปกรณ์ที่ใช้เก็บไฟล์ Backup

**สาเหตุที่พบบ่อย:**

- **Disk I/O ของอุปกรณ์ Backup ช้า:** ไม่ว่าจะเป็น Local Disk, SAN หรือ Network Share
    
- **Network Latency:** หากทำการ Backup ผ่านระบบเครือข่าย
    
- **Backup Compression:** การบีบอัดข้อมูลระหว่าง Backup ต้องใช้ CPU สูงขึ้น ซึ่งอาจทำให้การ Backup โดยรวมช้าลงได้
    

**สคริปต์ประกอบการวิเคราะห์:**


```sql
-- ตรวจสอบสถานะของ Job Backup ที่กำลังทำงานอยู่
SELECT
    session_id,
    command,
    start_time,
    status,
    percent_complete,
    wait_type,
    wait_time,
    wait_resource
FROM sys.dm_exec_requests
WHERE command LIKE '%BACKUP%';
```

---

### **SOS_SCHEDULER_YIELD**

**คำอธิบาย:** เกิดขึ้นเมื่อ Task ทำงานจนครบ Quantum (ปกติคือ 4ms) และต้องสละ CPU ให้ Task อื่นที่รออยู่ใน Runnable Queue Task ที่สละ CPU จะไปต่อท้ายใน Runnable Queue เพื่อรอ CPU อีกครั้ง การมี Wait Type นี้จำนวนมากบ่งชี้ว่ามี Task ที่พร้อมทำงานแย่ง CPU กันอยู่ หรือเกิดภาวะ CPU Bottleneck

**สาเหตุที่พบบ่อย:**

- **CPU Pressure:** มี Query ที่ต้องใช้ CPU หนักๆ ทำงานพร้อมกันจำนวนมาก
    
- **Parallelism ที่ไม่มีประสิทธิภาพ:** ทำให้เกิด Thread จำนวนมากและแย่ง CPU กัน
    
- **Spinlock Contention (พบน้อย):** การแย่งชิงทรัพยากรภายในที่ป้องกันด้วย Spinlock อย่างรุนแรง
    

**สคริปต์ประกอบการวิเคราะห์:**


```sql
-- ตรวจสอบจำนวน Task ที่รอใน Runnable Queue ของแต่ละ Scheduler
-- หาก runnable_tasks_count มีค่าสูงอย่างต่อเนื่อง แสดงว่ามี CPU pressure
SELECT
    scheduler_id,
    current_tasks_count,
    runnable_tasks_count,
    work_queue_count,
    load_factor
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255; -- กรองเอาเฉพาะ User Schedulers
```

---

### **THREADPOOL**

**คำอธิบาย:** เกิดขึ้นเมื่อไม่มี Worker Thread ว่างพอที่จะรับงานใหม่เข้ามาประมวลผล Task นั้นจึงต้องรอจนกว่าจะมี Worker Thread ว่าง

**สาเหตุที่พบบ่อย:**

- **Blocking หนัก:** มี Query จำนวนมากติด Block ทำให้ Worker Thread ไม่ถูกปล่อยคืนสู่ Pool
    
- **Max Worker Threads ไม่เพียงพอ:** (พบน้อยมาก) ค่า `max worker threads` ถูกตั้งไว้น้อยเกินไป
    
- **Parallel Query จำนวนมาก:** Query ที่ทำงานแบบขนานจะใช้ Worker Thread หลายตัว ทำให้ Thread ใน Pool หมดเร็วขึ้น
    

**สคริปต์ประกอบการวิเคราะห์:**


```sql
-- ตรวจสอบจำนวน Worker Thread ที่ใช้งานอยู่และรออยู่
SELECT
    (SELECT max_workers_count FROM sys.dm_os_sys_info) AS MaxWorkers,
    SUM(active_workers_count) AS CurrentWorkers,
    SUM(work_queue_count) AS TasksWaitingForThreads
FROM sys.dm_os_schedulers
WHERE status = 'VISIBLE ONLINE';
```

---

### **ASYNC_NETWORK_IO**

**คำอธิบาย:** เป็น Wait Type ที่เกิดขึ้นเมื่อ SQL Server ส่งผลลัพธ์กลับไปให้ Client แล้ว แต่กำลังรอ Client ตอบกลับว่าได้รับข้อมูลเรียบร้อยแล้ว ปัญหานี้มักจะไม่ได้เกิดจาก SQL Server หรือ Network แต่เกิดจากฝั่ง Application ที่ประมวลผลข้อมูลที่ได้รับไปได้ไม่เร็วพอ

**สาเหตุที่พบบ่อย:**

- **Row-By-Row Processing:** Application มีการดึงข้อมูลทีละแถวแล้วประมวลผล (เรียกว่า RBAR - Row-By-Agonizing-Row) ทำให้ SQL Server ต้องรอระหว่างการส่งข้อมูลแต่ละแถว
    
- **Client-side Resource Bottleneck:** เครื่อง Client มีทรัพยากร (CPU, Memory) ไม่เพียงพอ ทำให้ประมวลผลข้อมูลที่ได้รับได้ช้า
    
- **Network Latency (พบน้อย):** ปัญหาคอขวดที่ระบบเครือข่าย
    

**สคริปต์ประกอบการวิเคราะห์:**


```sql
-- ค้นหา Session ที่มี wait type เป็น ASYNC_NETWORK_IO
SELECT
    session_id,
    connect_time,
    last_request_start_time,
    last_request_end_time,
    program_name,
    host_name
FROM sys.dm_exec_sessions
WHERE session_id IN (
    SELECT session_id
    FROM sys.dm_exec_requests
    WHERE wait_type = 'ASYNC_NETWORK_IO'
);
```

---

### **RESOURCE_SEMAPHORE**

**คำอธิบาย:** เกิดขึ้นเมื่อ Query ต้องการใช้หน่วยความจำ (Memory Grant) ในการทำงาน (เช่น สำหรับการ Sort หรือ Hash Join) แต่หน่วยความจำที่ร้องขอไม่สามารถจัดสรรให้ได้ในทันที เนื่องจากมี Query อื่นใช้หน่วยความจำอยู่ ทำให้ต้องรอคิว

**สาเหตุที่พบบ่อย:**

- **Query ที่ไม่มีประสิทธิภาพ:** ขาด Index ที่เหมาะสม ทำให้เกิดการ Sort หรือ Hash Join กับข้อมูลจำนวนมาก
    
- **สถิติไม่อัปเดต:** ทำให้ Optimizer ประมาณการขนาด Memory Grant ผิดพลาด (สูงเกินจริง)
    
- **มี Query ที่ใช้ Memory จำนวนมากทำงานพร้อมกัน:** เกิดการแย่งชิง Memory Grant
    

**สคริปต์ประกอบการวิเคราะห์:**


```sql
-- ตรวจสอบ Memory Grant ที่กำลังใช้งานและที่กำลังรอ
SELECT
    session_id,
    wait_type,
    wait_duration_ms,
    grant_time, -- NULL หมายถึงกำลังรอ
    requested_memory_kb,
    granted_memory_kb,
    required_memory_kb,
    used_memory_kb,
    queue_id,
    wait_order
FROM sys.dm_exec_query_memory_grants;
```

---

### **LOGBUFFER**

**คำอธิบาย:** Wait Type นี้เกิดขึ้นเมื่อ Task ต้องการเขียน Log Record ลงใน Log Buffer แต่พื้นที่ใน Log Buffer เต็ม และกำลังรอให้มีการ Flush ข้อมูลลง Transaction Log File เพื่อให้มีพื้นที่ว่าง Wait Type นี้จะต่างจาก `WRITELOG` คือ `LOGBUFFER` เป็นการรอพื้นที่ว่างในหน่วยความจำ (Log Buffer) ส่วน `WRITELOG` คือการรอให้การเขียนจาก Buffer ลง Disk เสร็จสิ้น

**สาเหตุที่พบบ่อย:**

- **I/O ของ Log File ช้า:** ทำให้การ Flush Log Buffer ไปยัง Disk ช้า และทำให้ Buffer เต็มเร็ว
    
- **Transaction ขนาดใหญ่มาก:** ทำให้สร้าง Log Record จำนวนมากอย่างรวดเรวจนเต็ม Log Buffer
    

**สคริปต์ประกอบการวิเคราะห์:**


```sql
-- ตรวจสอบสถิติของ LOGBUFFER waits
SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms
FROM sys.dm_os_wait_stats
WHERE wait_type = 'LOGBUFFER';
```

---

### **ASYNC_IO_COMPLETION**

**คำอธิบาย:** เป็นการรอการทำงานของ I/O ที่ **ไม่เกี่ยวข้อง** กับ Data Page โดยตรง ตัวอย่างเช่น การขยายขนาดไฟล์ข้อมูลหรือไฟล์ Log (Auto-growth), การเขียนข้อมูลลงไฟล์ Backup, การสร้างฐานข้อมูล, หรือการทำงานของ Lazy Writer

**สาเหตุที่พบบ่อย:**

- **การขยายขนาดไฟล์ (Auto-growth):** เป็นการทำงานที่ช้าและทำให้เกิด Wait Type นี้ได้
    
- **การ Backup/Restore:** โดยเฉพาะกับฐานข้อมูลขนาดใหญ่
    
- **I/O Subsystem ช้า:** เป็นปัญหาโดยรวมของระบบจัดเก็บข้อมูล
    

**สคริปต์ประกอบการวิเคราะห์:**


```sql
-- ตรวจสอบ I/O request ที่ยังค้างอยู่
SELECT
    session_id,
    io_type,
    io_pending_ms_avg,
    io_handle
FROM sys.dm_io_pending_io_requests;
```

---

### **IO_COMPLETION**

**คำอธิบาย:** คล้ายกับ `ASYNC_IO_COMPLETION` แต่เกิดขึ้นกับการทำงานของ I/O แบบ Synchronous ที่ไม่เกี่ยวข้องกับ Data Page เช่น การอ่านข้อมูลจาก Transaction Log เพื่อทำการ Rollback หรือการอ่านข้อมูลสำหรับ Transactional Replication

**สาเหตุที่พบบ่อย:**

- **การ Rollback Transaction ขนาดใหญ่:** ต้องอ่าน Log File จำนวนมาก
    
- **การทำงานของ Transactional Replication:** ที่ต้องอ่าน Log
    
- **I/O Subsystem ช้า:** ปัญหาโดยรวมของระบบจัดเก็บข้อมูล
    

**สคริปต์ประกอบการวิเคราะห์:** สามารถใช้สคริปต์เดียวกับ `ASYNC_IO_COMPLETION` เพื่อตรวจสอบ I/O ที่ค้างอยู่ได้

---

### **CMEMTHREAD**

**คำอธิบาย:** เกิดขึ้นเมื่อ Thread กำลังรอการเข้าถึง Memory Object ที่มีการป้องกันแบบ Thread-Safe ปัญหานี้มักเกี่ยวข้องกับการแย่งชิงกันเพื่อจัดสรรหรือเข้าถึงโครงสร้างข้อมูลในหน่วยความจำ ส่วนใหญ่มักพบเมื่อมีการ Compile Query จำนวนมากพร้อมๆ กัน ทำให้เกิดการแย่งชิงเพื่อเขียนหรืออ่านข้อมูลใน Plan Cache

**สาเหตุที่พบบ่อย:**

- **Ad-hoc Workload หนักๆ:** มีการส่ง Query ที่แตกต่างกันจำนวนมากเข้ามา ทำให้เกิดการ Compile และแย่งชิง Memory Object ที่ใช้จัดการ Plan Cache
    
- **Plan Cache Bloat:** Plan Cache มีขนาดใหญ่และมี Plan ที่ไม่ได้ใช้จำนวนมาก ทำให้การจัดการ Cache ต้องใช้ทรัพยากรสูงขึ้น
    

**สคริปต์ประกอบการวิเคราะห์:**


```sql
-- ตรวจสอบ Memory Clerk ที่มีการแย่งชิงกันสูง
-- สังเกต Clerk ที่เกี่ยวข้องกับ Plan Cache เช่น CACHESTORE_SQLCP, CACHESTORE_OBJCP
SELECT
    type,
    name,
    pages_kb,
    entries_count
FROM sys.dm_os_memory_clerks
ORDER BY pages_kb DESC;
```
