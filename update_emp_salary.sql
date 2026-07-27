CREATE OR REPLACE PROCEDURE update_emp_salary (
    p_emp_id     IN  NUMBER,
    p_raise_amt  IN  NUMBER,
    p_new_salary OUT NUMBER
) IS 
    -- Local variable definition
    v_current_salary NUMBER;
BEGIN
    -- 1. Fetch current salary and lock the row for the transaction
    SELECT salary INTO v_current_salary
    FROM employees
    WHERE employee_id = p_emp_id
    FOR UPDATE;

    -- 2. Calculate the updated value
    p_new_salary := v_current_salary + p_raise_amt;

    -- 3. Execute the DML update
    UPDATE employees
    SET salary = p_new_salary
    WHERE employee_id = p_emp_id;

    -- 4. Print confirmation to the server output
    DBMS_OUTPUT.PUT_LINE('Successfully updated Employee ID ' || p_emp_id);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Error: Employee ID ' || p_emp_id || ' does not exist.');
        p_new_salary := 0;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An unexpected error occurred: ' || SQLERRM);
        RAISE;
END update_emp_salary;
/
