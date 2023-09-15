SELECT pp.ProductID, pp.Name , ss.SalesOrderID, ss.SalesOrderDetailID, pr.FirstName
FROM Production.Product AS pp 
JOIN Sales.SalesOrderDetail AS ss
ON pp.ProductID=ss.ProductID
JOIN Person.Person AS pr
ON  CAST(pr.FirstName AS char(1)) = CAST(pp.Name AS char(1));
