
USE StoreDB;
GO

/*==============================================================
1. Customer Spending Analysis
==============================================================*/
DECLARE @CustomerID INT = 1;
DECLARE @TotalSpent DECIMAL(18,2);

SELECT 
    @TotalSpent = SUM(oi.quantity * oi.list_price * (1 - oi.discount))
FROM sales.orders o
JOIN sales.order_items oi ON o.order_id = oi.order_id
WHERE o.customer_id = @CustomerID
  AND o.order_status = 4;

IF @TotalSpent > 5000
    PRINT 'Customer ID ' + CAST(@CustomerID AS VARCHAR) +
          ' is a VIP customer. Total Spent = $' + CAST(@TotalSpent AS VARCHAR);
ELSE
    PRINT 'Customer ID ' + CAST(@CustomerID AS VARCHAR) +
          ' is a Regular customer. Total Spent = $' + CAST(@TotalSpent AS VARCHAR);

GO

/*==============================================================
2. Product Price Threshold Report
==============================================================*/
DECLARE @ThresholdPrice DECIMAL(10,2) = 1500;
DECLARE @ProductCount INT;

SELECT @ProductCount = COUNT(*)
FROM production.products
WHERE list_price > @ThresholdPrice;

PRINT 'Products costing more than $' + CAST(@ThresholdPrice AS VARCHAR) +
      ': ' + CAST(@ProductCount AS VARCHAR);

GO

/*==============================================================
3. Staff Performance Calculator
==============================================================*/
DECLARE @StaffID INT = 2;
DECLARE @Year INT = 2017;
DECLARE @TotalSales DECIMAL(18,2);

SELECT 
    @TotalSales = SUM(oi.quantity * oi.list_price * (1 - oi.discount))
FROM sales.orders o
JOIN sales.order_items oi ON o.order_id = oi.order_id
WHERE o.staff_id = @StaffID
  AND YEAR(o.order_date) = @Year
  AND o.order_status = 4;

PRINT 'Staff ID: ' + CAST(@StaffID AS VARCHAR) +
      ' | Year: ' + CAST(@Year AS VARCHAR) +
      ' | Total Sales: $' + ISNULL(CAST(@TotalSales AS VARCHAR), '0');

GO

/*==============================================================
4. Global Variables Information
==============================================================*/
SELECT 
    @@SERVERNAME AS ServerName,
    @@VERSION AS SQLServerVersion;

SELECT * FROM production.products;
SELECT @@ROWCOUNT AS RowsAffected;

GO

/*==============================================================
5. Inventory Level Check
==============================================================*/
DECLARE @ProductID INT = 1;
DECLARE @StoreID INT = 1;
DECLARE @Quantity INT;

SELECT @Quantity = quantity
FROM production.stocks
WHERE product_id = @ProductID
  AND store_id = @StoreID;

IF @Quantity > 20
    PRINT 'Well stocked';
ELSE IF @Quantity BETWEEN 10 AND 20
    PRINT 'Moderate stock';
ELSE
    PRINT 'Low stock - reorder needed';

GO

/*==============================================================
6. WHILE Loop – Update Low Stock Items in Batches
==============================================================*/
DECLARE @RowsAffected INT = 1;

WHILE @RowsAffected > 0
BEGIN
    UPDATE TOP (3) production.stocks
    SET quantity = quantity + 10
    WHERE quantity < 5;

    SET @RowsAffected = @@ROWCOUNT;

    PRINT CAST(@RowsAffected AS VARCHAR) + ' products restocked in this batch';
END;

GO

/*==============================================================
7. Product Price Categorization
==============================================================*/
SELECT 
    product_name,
    list_price,
    CASE
        WHEN list_price < 300 THEN 'Budget'
        WHEN list_price BETWEEN 300 AND 800 THEN 'Mid-Range'
        WHEN list_price BETWEEN 801 AND 2000 THEN 'Premium'
        ELSE 'Luxury'
    END AS PriceCategory
FROM production.products;

GO

/*==============================================================
8. Customer Order Validation
==============================================================*/
DECLARE @CheckCustomerID INT = 5;
DECLARE @OrderCount INT;

IF EXISTS (SELECT 1 FROM sales.customers WHERE customer_id = @CheckCustomerID)
BEGIN
    SELECT @OrderCount = COUNT(*)
    FROM sales.orders
    WHERE customer_id = @CheckCustomerID;

    PRINT 'Customer exists. Total Orders = ' + CAST(@OrderCount AS VARCHAR);
END
ELSE
BEGIN
    PRINT 'Customer does not exist.';
END;

GO

/*==============================================================
9. Shipping Cost Calculator Function
==============================================================*/
CREATE OR ALTER FUNCTION dbo.CalculateShipping (@OrderTotal DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN 
        CASE
            WHEN @OrderTotal > 100 THEN 0
            WHEN @OrderTotal BETWEEN 50 AND 99 THEN 5.99
            ELSE 12.99
        END;
END;
GO

/*==============================================================
10. Product Category Function (Inline Table-Valued Function)
==============================================================*/
CREATE OR ALTER FUNCTION dbo.GetProductsByPriceRange
(
    @MinPrice DECIMAL(10,2),
    @MaxPrice DECIMAL(10,2)
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        p.product_id,
        p.product_name,
        p.list_price,
        b.brand_name,
        c.category_name
    FROM production.products p
    JOIN production.brands b ON p.brand_id = b.brand_id
    JOIN production.categories c ON p.category_id = c.category_id
    WHERE p.list_price BETWEEN @MinPrice AND @MaxPrice
);
GO

/*==============================================================
11. Customer Sales Summary Function (Multi-Statement)
==============================================================*/
CREATE OR ALTER FUNCTION dbo.GetCustomerYearlySummary (@CustomerID INT)
RETURNS @Summary TABLE
(
    SalesYear INT,
    TotalOrders INT,
    TotalSpent DECIMAL(18,2),
    AvgOrderValue DECIMAL(18,2)
)
AS
BEGIN
    INSERT INTO @Summary
    SELECT
        YEAR(o.order_date),
        COUNT(DISTINCT o.order_id),
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)),
        AVG(oi.quantity * oi.list_price * (1 - oi.discount))
    FROM sales.orders o
    JOIN sales.order_items oi ON o.order_id = oi.order_id
    WHERE o.customer_id = @CustomerID
      AND o.order_status = 4
    GROUP BY YEAR(o.order_date);

    RETURN;
END;
GO

/*==============================================================
12. Discount Calculation Function
==============================================================*/
CREATE OR ALTER FUNCTION dbo.CalculateBulkDiscount (@Quantity INT)
RETURNS DECIMAL(4,2)
AS
BEGIN
    RETURN 
        CASE
            WHEN @Quantity BETWEEN 1 AND 2 THEN 0.00
            WHEN @Quantity BETWEEN 3 AND 5 THEN 0.05
            WHEN @Quantity BETWEEN 6 AND 9 THEN 0.10
            ELSE 0.15
        END;
END;
GO
