--CREATE HEAP Table
SELECT
*
INTO Production.Product2
FROM Production.Product;
GO

---Test 1 Generate Estimated Execution Plan 
SELECT * FROM Production.Product2
WHERE Color='Grey' 
GO

--Create Non-Clustered Index on Color column ON HEAP TABLE
CREATE NONCLUSTERED INDEX [NIDX_Product2_Color] ON [Production].[Product2]
(
	[Color] ASC
)
GO

---Test 1 Generate Estimated Execution Plan (NIDX on HEAP)

SELECT * FROM Production.Product2
WHERE Color='Grey' 
GO

--Add Primary Key (Cluster Key)
ALTER TABLE Production.Product2 ADD CONSTRAINT
	PK_Product2 PRIMARY KEY CLUSTERED 
	(
	ProductID
	)
GO

---Test 2 Generate Estimated Execution Plan (NIDX on Clustered Index)
SELECT * FROM Production.Product2
WHERE Color='Grey' 
GO
---Test 3 Generate Estimated Execution Plan (NIDX on Clustered Index)
SELECT color FROM Production.Product2 --Covered Index
WHERE Color='Grey' 
GO
---Test 4 Generate Estimated Execution Plan (NIDX on Clustered Index)
SELECT color,ProductID FROM Production.Product2 --Covered Index
WHERE Color='Grey' 
GO
---Test 5 Generate Estimated Execution Plan (NIDX on Clustered Index)
SELECT color,ProductID,ProductLine FROM Production.Product2
WHERE Color='Grey' 
GO
