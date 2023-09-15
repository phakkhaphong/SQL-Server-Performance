--SET STATISTICS XML ON;
--SET SHOWPLAN_TEXT ON;
--SET SHOWPLAN_ALL ON;
--SET STATISTICS PROFILE ON;
--GO
	SELECT pp.ProductID, pp.Name , ss.SalesOrderID, ss.SalesOrderDetailID, pr.FirstName
	FROM Production.Product AS pp 
	JOIN Sales.SalesOrderDetail AS ss
	ON pp.ProductID=ss.ProductID
	JOIN Person.Person AS pr
	ON  CAST(pr.FirstName AS char(1)) = CAST(pp.Name AS char(1));
	GO
--SET STATISTICS XML OFF;
--SET SHOWPLAN_TEXT OFF;
--SET SHOWPLAN_ALL ON;
--SET STATISTICS PROFILE OFF;
--GO
