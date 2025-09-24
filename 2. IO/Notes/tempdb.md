## ระบบภายในของ tempdb (tempdb Internals)

### วัตถุประสงค์ของบทเรียน
หลังจากเสร็จสิ้นบทเรียนนี้ คุณจะสามารถ:
- เข้าใจหน้าที่และความสำคัญของ tempdb
- กำหนดค่า tempdb สำหรับประสิทธิภาพสูงสุด
- แก้ไขปัญหาที่เกี่ยวข้องกับ tempdb
- ตรวจสอบการใช้งาน tempdb

### ความสำคัญของ tempdb

#### หน้าที่หลักของ tempdb
1. **Temporary Tables และ Table Variables**
2. **Internal Work Tables** สำหรับ sorting และ hashing
3. **Version Store** สำหรับ Row Versioning
4. **Service Broker** queues
5. **XML processing**
6. **MARS (Multiple Active Result Sets)**

#### ลักษณะพิเศษของ tempdb
- **Global Resource**: ใช้ร่วมกันโดยทุก Database
- **Recreated on Restart**: สร้างใหม่ทุกครั้งที่ SQL Server restart
- **Simple Recovery Model**: ไม่สามารถเปลี่ยนได้

### การกำหนดค่า tempdb

#### จำนวนไฟล์ข้อมูล
```sql
-- แนะนำ: จำนวนไฟล์เท่ากับจำนวน CPU Cores (สูงสุด 8 ไฟล์)
-- หากมี CPU มากกว่า 8 cores เริ่มจาก 8 ไฟล์และเพิ่มทีละ 4 หากจำเป็น

-- ตรวจสอบจำนวน CPU
SELECT cpu_count FROM sys.dm_os_sys_info;

-- ดู tempdb files ปัจจุบัน
SELECT 
    name,
    physical_name,
    size * 8 / 1024 AS 'Size (MB)',
    growth
FROM tempdb.sys.database_files;
```

#### การเพิ่มไฟล์ข้อมูลใน tempdb
```sql
-- เพิ่ม Data File ใน tempdb
ALTER DATABASE tempdb
ADD FILE (
    NAME = 'tempdev2',
    FILENAME = 'C:\TempDB\tempdev2.ndf',
    SIZE = 100MB,
    FILEGROWTH = 10MB
);

-- เพิ่ม Data File อีกไฟล์
ALTER DATABASE tempdb
ADD FILE (
    NAME = 'tempdev3',
    FILENAME = 'C:\TempDB\tempdev3.ndf',
    SIZE = 100MB,
    FILEGROWTH = 10MB
);
```

### การจัดวางไฟล์ tempdb

#### ข้อแนะนำการจัดวางไฟล์
1. **แยก tempdb จาก User Databases**
2. **ใช้ Fast Storage** (SSD หรือ high-speed disks)
3. **วางในไดร์ฟเฉพาะ** เพื่อลด I/O contention
4. **ขนาดไฟล์เท่ากัน** เพื่อการกระจายโหลดที่เท่าเทียม

#### การตั้งค่าขนาดไฟล์
```sql
-- ปรับขนาดไฟล์ tempdb ให้เท่ากัน
ALTER DATABASE tempdb
MODIFY FILE (
    NAME = 'tempdev',
    SIZE = 100MB,
    FILEGROWTH = 10MB
);

ALTER DATABASE tempdb
MODIFY FILE (
    NAME = 'tempdev2',
    SIZE = 100MB,
    FILEGROWTH = 10MB
);
```

### การตรวจสอบประสิทธิภาพ tempdb

#### ตรวจสอบการใช้พื้นที่
```sql
-- ดูการใช้พื้นที่ใน tempdb
SELECT 
    SUM(unallocated_extent_page_count) AS [free pages],
    SUM(unallocated_extent_page_count) * 8 / 1024 AS [free space (MB)]
FROM tempdb.sys.dm_db_file_space_usage;

-- ดูการใช้พื้นที่แยกตามประเภท
SELECT 
    user_object_reserved_page_count * 8 / 1024 AS [User Objects (MB)],
    internal_object_reserved_page_count * 8 / 1024 AS [Internal Objects (MB)],
    version_store_reserved_page_count * 8 / 1024 AS [Version Store (MB)]
FROM tempdb.sys.dm_db_file_space_usage;
```

#### ตรวจสอบ Page Allocation Contention
```sql
-- ตรวจสอบ wait statistics สำหรับ tempdb contention
SELECT 
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    max_wait_time_ms,
    signal_wait_time_ms
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'PAGE%LATCH%'
AND wait_type IN ('PAGELATCH_UP', 'PAGELATCH_EX', 'PAGEIOLATCH_UP', 'PAGEIOLATCH_EX');
```

### การแก้ไขปัญหา tempdb

#### ปัญหาที่พบบ่อยและการแก้ไข
1. **Allocation Contention**:
   - เพิ่มจำนวนไฟล์ข้อมูล
   - ใช้ Trace Flag 1118

2. **Space Issues**:
   - ตรวจสอบ queries ที่ใช้ tempdb มาก
   - ปรับขนาด initial size

3. **I/O Bottlenecks**:
   - ย้าย tempdb ไป fast storage
   - แยกไฟล์ log ออกจากไฟล์ data

#### การใช้ Trace Flags
```sql
-- ตรวจสอบ Trace Flags ที่เปิดอยู่
DBCC TRACESTATUS(-1);

-- เปิด Trace Flag 1118 (Uniform Extent Allocation)
DBCC TRACEON(1118, -1);

-- เปิด Trace Flag 1117 (Grow all files in filegroup equally)
DBCC TRACEON(1117, -1);
```

### แนวปฏิบัติที่ดี tempdb
- ตั้งค่าจำนวนไฟล์เท่ากับจำนวน CPU cores
- ขนาดไฟล์ทุกไฟล์เท่ากัน
- ตั้งค่า initial size ให้เพียงพอ
- วางไฟล์ใน fast, dedicated storage
- เปิดใช้งาน Trace Flags 1117 และ 1118
- ตรวจสอบการใช้งานอย่างสม่ำเสมอ

---

