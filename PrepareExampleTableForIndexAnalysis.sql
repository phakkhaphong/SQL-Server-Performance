USE AdventureWorks;
GO

SELECT * 
INTO [Sales].[SalesOrderHeader_HEAP]
FROM [Sales].[SalesOrderHeader];
GO

SELECT * 
INTO [Sales].[SalesOrderHeader_CLUSTER]
FROM [Sales].[SalesOrderHeader];
GO

ALTER TABLE Sales.SalesOrderHeader_CLUSTER 
ADD CONSTRAINT PK_SalesOrderHeader_CLUSTER PRIMARY KEY CLUSTERED (SalesOrderID)
GO
