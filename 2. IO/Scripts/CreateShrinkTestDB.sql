use master

DROP DATABASE IF EXISTS AdventureWorks;

RESTORE DATABASE AdventureWorks FROM  DISK = N'D:\SetupFiles\AdventureWorks.bak' WITH  REPLACE,
MOVE N'AdventureWorks_Data' TO N'D:\SQLDATA\AdventureWorks.mdf', 
MOVE N'AdventureWorks_Log' TO N'D:\SQLDATA\AdventureWorks.ldf',
MOVE N'AdventureWorks_mod' TO N'D:\SQLDATA\AdventureWorks_mod'
GO
ALTER AUTHORIZATION ON DATABASE::AdventureWorks TO sa;
GO

DROP DATABASE IF EXISTS shrinktest;
-- for setup.cmd
-- create a database for showing the effect of shrink on fragmentation
USE [master]
GO
CREATE DATABASE [shrinktest]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'shrinktest_data', FILENAME = N'D:\SQLDATA\shrinktest_data.mdf' , SIZE = 524288KB , FILEGROWTH = 64MB )
 LOG ON 
( NAME = N'shrinktest_log', FILENAME = N'D:\SQLDATA\shrinktest_log.ldf' , SIZE = 32MB , FILEGROWTH = 8MB);
GO
ALTER AUTHORIZATION ON DATABASE::shrinktest TO sa;
GO


USE shrinktest;
GO
select * into dbo.testtable from AdventureWorks.Sales.SalesOrderDetail;
GO

DECLARE @i int =1;
WHILE @i <=5
BEGIN
	insert into shrinktest.dbo.testtable select [SalesOrderID],[CarrierTrackingNumber],[OrderQty],[ProductID],[SpecialOfferID]
      ,[UnitPrice],[UnitPriceDiscount],[LineTotal],[rowguid],[ModifiedDate] from AdventureWorks.Sales.SalesOrderDetail;
	  SET @i = @i +1;
END
GO
create index idx1_testtable on shrinktest.dbo.testtable (salesOrderID);
GO
create index idx2_testtable on shrinktest.dbo.testtable (carrierTrackingNumber,SalesOrderId);
GO
create index idx3_testtable on shrinktest.dbo.testtable (ModifiedDate);
GO
