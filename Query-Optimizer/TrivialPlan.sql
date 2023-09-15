-- Trivial plan

-- Enable Actual Execution Plan (Ctrl+M), then execute the following query.
-- On the Execution plan tab in the results pane, right-click the left-most operator (SELECT cost 0%) 
-- and click Properties (keyboard F4).
-- In the Properties pane, notice that the "Optimization Level" attribute has the value "TRIVIAL"

SELECT * FROM HumanResources.Employee;
