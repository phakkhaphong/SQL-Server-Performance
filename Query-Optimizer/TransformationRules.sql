-- Transformation Rules

-- Execute all the code for this step in one go
-- The results will show the transformation rules in sys.dm_exec_query_transformation_stats
-- which were used in compiling a plan for the SELECT statement.

DROP TABLE IF EXISTS #transformation_stats_before_query_execution;
DROP TABLE IF EXISTS #transformation_stats_after_query_execution;
DROP TABLE IF EXISTS #result;

SELECT *
INTO #transformation_stats_before_query_execution
FROM sys.dm_exec_query_transformation_stats;

--This is the statement we are interested in results for
SELECT pp.ProductID, Count(*) ProductCount 
INTO #result
FROM Production.Product pp JOIN Sales.SalesOrderDetail ss
ON pp.ProductID=ss.ProductID
WHERE ss.OrderQty > 10
GROUP BY pp.ProductID
OPTION (RECOMPILE);

SELECT *
INTO #transformation_stats_after_query_execution
FROM sys.dm_exec_query_transformation_stats;


--Review
SELECT * FROM #transformation_stats_after_query_execution WHERE succeeded > 0
EXCEPT
SELECT * FROM #transformation_stats_before_query_execution ;
