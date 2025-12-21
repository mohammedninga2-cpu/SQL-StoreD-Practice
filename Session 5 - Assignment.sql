USE StoreDB;
GO

/* =========================================================
Q1. Classify all products into price categories
- Economy: under $300
- Standard: $300–$999
- Premium: $1000–$2499
- Luxury: $2500 and above
========================================================= */
SELECT
    product_id,
    product_name,
    list_price,
    CASE
        WHEN list_price < 300 THEN 'Economy'
        WHEN list_price BETWEEN 300 AND 999 THEN 'Standard'
        WHEN list_price BETWEEN 1000 AND 2499 THEN 'Premium'
        ELSE 'Luxury'
    END AS price_category
FROM production.products
ORDER BY list_price;
GO


/* =========================================================
Q2. Show order processing info with user-friendly status
and priority level based on order age
========================================================= */
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,

    -- User-friendly status description
    CASE o.order_status
        WHEN 1 THEN 'Order Received'
        WHEN 2 THEN 'In Preparation'
        WHEN 3 THEN 'Order Cancelled'
        WHEN 4 THEN 'Order Delivered'
        ELSE 'Unknown Status'
    END AS status_description,

    -- Priority level
    CASE
        WHEN o.order_status = 1
             AND DATEDIFF(DAY, o.order_date, GETDATE()) > 5
            THEN 'URGENT'
        WHEN o.order_status = 2
             AND DATEDIFF(DAY, o.order_date, GETDATE()) > 3
            THEN 'HIGH'
        ELSE 'NORMAL'
    END AS priority_level
FROM sales.orders o
ORDER BY o.order_date;
GO


/* =========================================================
Q3. Categorize staff based on number of orders handled
========================================================= */
SELECT
    s.staff_id,
    s.first_name,
    s.last_name,
    COUNT(o.order_id) AS total_orders,
    CASE
        WHEN COUNT(o.order_id) = 0 THEN 'New Staff'
        WHEN COUNT(o.order_id) BETWEEN 1 AND 10 THEN 'Junior Staff'
        WHEN COUNT(o.order_id) BETWEEN 11 AND 25 THEN 'Senior Staff'
        ELSE 'Expert Staff'
    END AS staff_level
FROM sales.staffs s
LEFT JOIN sales.orders o
    ON s.staff_id = o.staff_id
GROUP BY
    s.staff_id,
    s.first_name,
    s.last_name
ORDER BY total_orders DESC;
GO


/* =========================================================
Q4. Handle missing customer contact information
========================================================= */
SELECT
    customer_id,
    first_name,
    last_name,

    -- Replace NULL phone
    ISNULL(phone, 'Phone Not Available') AS phone,

    email,
    street,
    city,
    state,
    zip_code,

    -- Preferred contact method
    COALESCE(phone, email, 'No Contact Method') AS preferred_contact
FROM sales.customers
ORDER BY customer_id;
GO


/* =========================================================
Q5. Safely calculate price per unit in stock (Store 1 only)
========================================================= */
SELECT
    p.product_id,
    p.product_name,
    p.list_price,
    s.quantity,

    -- Safe price per unit calculation
    ISNULL(
        p.list_price / NULLIF(s.quantity, 0),
        0
    ) AS price_per_unit,

    -- Stock status
    CASE
        WHEN s.quantity = 0 THEN 'Out of Stock'
        WHEN s.quantity BETWEEN 1 AND 10 THEN 'Low Stock'
        ELSE 'In Stock'
    END AS stock_status
FROM production.stocks s
JOIN production.products p
    ON s.product_id = p.product_id
WHERE s.store_id = 1
ORDER BY p.product_name;
GO


/* =========================================================
Q6. Format complete customer addresses safely
========================================================= */
SELECT
    customer_id,
    first_name,
    last_name,

    -- Formatted full address
    TRIM(
        COALESCE(street, 'Street Not Available') + ', ' +
        COALESCE(city, 'City Not Available') + ', ' +
        COALESCE(state, 'State Not Available') +
        CASE
            WHEN zip_code IS NOT NULL THEN ' ' + zip_code
            ELSE ''
        END
    ) AS formatted_address
FROM sales.customers
ORDER BY customer_id;
GO


/* =========================================================
Q7. Use a CTE to find customers who spent more than $1500
========================================================= */
WITH customer_spending AS (
    SELECT
        o.customer_id,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spent
    FROM sales.orders o
    JOIN sales.order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 4 -- Completed orders only
    GROUP BY o.customer_id
    HAVING SUM(oi.quantity * oi.list_price * (1 - oi.discount)) > 1500
)
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.phone,
    cs.total_spent
FROM customer_spending cs
JOIN sales.customers c
    ON cs.customer_id = c.customer_id
ORDER BY cs.total_spent DESC;
GO

