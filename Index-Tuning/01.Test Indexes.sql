--CREATE Test Table
SELECT
*
INTO Production.Product2
FROM Production.Product;
GO

---Test 1 Generate Estimated Execution Plan
SELECT * FROM Production.Product2
WHERE Color='Red' 
GO

--Add Primary Key (Cluster Key)
ALTER TABLE Production.Product2 ADD CONSTRAINT
	PK_Product2 PRIMARY KEY CLUSTERED 
	(
	ProductID
	)
GO

--Create Non-Clustered Index on Color column
CREATE NONCLUSTERED INDEX [NIDX_Product2_Color] ON [Production].[Product2]
(
	[Color] ASC
)
GO

--Test 2 Generate Estimated Execution Plan
SELECT * FROM Production.Product2
WHERE Color='Red' 
GO

--Test 3 Generate Estimated Execution Plan


SELECT * FROM Production.Product2
WHERE Color='White'
GO

--Test 4 Traditional Cover-Index 
--Generate Estimated Execution Plan

SELECT P.ProductID,P.Color FROM Production.Product2 as P
WHERE P.Color='White'
GO

--Test 5 Non-Cover-Index (Lookup TABLE Content)
SELECT P.ProductID,P.Color,P.ListPrice FROM Production.Product2 as P
WHERE P.Color='White'
GO
