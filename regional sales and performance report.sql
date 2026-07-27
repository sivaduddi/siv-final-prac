-- CTE 1: Aggregate and clean baseline transactional data
WITH RawMonthlyRevenue AS (
    SELECT 
        o.region_id,
        o.department_id,
        o.employee_id,
        DATE_TRUNC('month', o.order_date) AS fiscal_month,
        SUM(o.amount) AS gross_sales,
        COUNT(DISTINCT o.id) AS total_orders,
        COUNT(DISTINCT o.customer_name) AS unique_customers
    FROM orders o
    INNER JOIN employees e ON o.employee_id = e.id
    WHERE o.status = 'Completed'
      AND o.order_date >= '2025-01-01'
    GROUP BY 
        o.region_id, 
        o.department_id, 
        o.employee_id, 
        DATE_TRUNC('month', o.order_date)
),

-- CTE 2: Calculate window-based rankings and local metrics per department
EmployeeRankings AS (
    SELECT 
        rmr.fiscal_month,
        rmr.region_id,
        rmr.department_id,
        rmr.employee_id,
        rmr.gross_sales,
        rmr.total_orders,
        -- Rank employees inside their specific department by sales volume
        ROW_NUMBER() OVER (
            PARTITION BY rmr.fiscal_month, rmr.department_id 
            ORDER BY rmr.gross_sales DESC
        ) AS dept_sales_rank,
        -- Calculate a running regional total revenue up to the current month
        SUM(rmr.gross_sales) OVER (
            PARTITION BY rmr.region_id 
            ORDER BY rmr.fiscal_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_regional_revenue
    FROM RawMonthlyRevenue rmr
),

-- CTE 3: Establish baseline benchmarks for comparisons
CompanyBenchmarks AS (
    SELECT 
        AVG(gross_sales) AS avg_historical_employee_sales,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gross_sales) AS median_employee_sales
    FROM RawMonthlyRevenue
)

-- Main Query: Combine dimensions, metrics, rankings, and logic
SELECT 
    er.fiscal_month,
    r.region_name AS region,
    d.name AS department_name,
    CONCAT(e.first_name, ' ', e.last_name) AS top_performer_name,
    er.gross_sales AS top_performer_sales,
    er.total_orders AS top_performer_orders,
    er.running_regional_revenue,
    
    -- Conditional Flagging using CASE WHEN
    CASE 
        WHEN er.gross_sales >= cb.avg_historical_employee_sales * 1.5 THEN 'Elite Performance'
        WHEN er.gross_sales < cb.median_employee_sales THEN 'Needs Review'
        ELSE 'On Target'
    END AS performance_tier,
    
    -- Numerical comparison against company-wide benchmark
    ROUND(er.gross_sales - cb.avg_historical_employee_sales, 2) AS variance_from_average

FROM EmployeeRankings er
CROSS JOIN CompanyBenchmarks cb  -- Multiplies benchmark rows against data rows safely
INNER JOIN employees e ON er.employee_id = e.id
INNER JOIN departments d ON er.department_id = d.id
INNER JOIN regions r ON er.region_id = r.id
WHERE er.dept_sales_rank = 1  -- Filter explicitly for the top performer in every department

ORDER BY 
    er.fiscal_month DESC, 
    er.gross_sales DESC;
