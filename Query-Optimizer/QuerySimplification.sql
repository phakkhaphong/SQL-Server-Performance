USE AdventureWorks;

--query simplification 1
-- Highlight this query and generate an estimated execution plan (Ctrl+L)

SELECT
	P.ProductID
,	P.ProductNumber
--,	O.OrderDate
FROM Production.Product as P
INNER JOIN Sales.SalesOrderDetail as OD ON P.ProductID=OD.ProductID
INNER JOIN Sales.SalesOrderHeader as O ON OD.SalesOrderID=O.SalesOrderID;

--query simplification 2
-- Highlight this query and generate an estimated execution plan (Ctrl+L)

SELECT * FROM HumanResources.Employee WHERE SickLeaveHours=500;
