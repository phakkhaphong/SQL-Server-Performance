CREATE DATABASE [Memdemo]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'Memdemo', FILENAME = N'D:\SQLDATA\Memdemo.mdf' , SIZE = 8192KB , FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'Memdemo_log', FILENAME = N'D:\SQLDATA\Memdemo_log.ldf' , SIZE = 8192KB , FILEGROWTH = 65536KB )
GO
ALTER DATABASE [Memdemo] ADD FILEGROUP [MemFG] CONTAINS MEMORY_OPTIMIZED_DATA 
GO
ALTER DATABASE [Memdemo] ADD FILE ( NAME = N'Memdata', FILENAME = N'D:\SQLDATA\Memdata' ) TO FILEGROUP [MemFG]
GO
