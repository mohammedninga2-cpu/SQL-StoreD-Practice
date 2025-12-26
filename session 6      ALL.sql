USE StoreDB;
GO
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

/*==============================================================
13. Customer Order History Procedure
==============================================================*/
CREATE OR ALTER PROCEDURE sp_GetCustomerOrderHistory
    @CustomerID INT,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SELECT
        o.order_id,
        o.order_date,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS OrderTotal
    FROM sales.orders o
    JOIN sales.order_items oi ON o.order_id = oi.order_id
    WHERE o.customer_id = @CustomerID
      AND (@StartDate IS NULL OR o.order_date >= @StartDate)
      AND (@EndDate IS NULL OR o.order_date <= @EndDate)
    GROUP BY o.order_id, o.order_date
    ORDER BY o.order_date DESC;
END;
GO

/*==============================================================
14. Inventory Restock Procedure
==============================================================*/
CREATE OR ALTER PROCEDURE sp_RestockProduct
    @StoreID INT,
    @ProductID INT,
    @RestockQty INT,
    @OldQty INT OUTPUT,
    @NewQty INT OUTPUT,
    @Success BIT OUTPUT
AS
BEGIN
    SELECT @OldQty = quantity
    FROM production.stocks
    WHERE store_id = @StoreID AND product_id = @ProductID;

    IF @OldQty IS NULL
    BEGIN
        SET @Success = 0;
        RETURN;
    END

    UPDATE production.stocks
    SET quantity = quantity + @RestockQty
    WHERE store_id = @StoreID AND product_id = @ProductID;

    SELECT @NewQty = quantity
    FROM production.stocks
    WHERE store_id = @StoreID AND product_id = @ProductID;

    SET @Success = 1;
END;
GO

/*==============================================================
15. Order Processing Procedure
==============================================================*/
CREATE OR ALTER PROCEDURE sp_ProcessNewOrder
    @CustomerID INT,
    @ProductID INT,
    @Quantity INT,
    @StoreID INT
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @OrderID INT;

        INSERT INTO sales.orders
        (customer_id, order_status, order_date, required_date, store_id, staff_id)
        VALUES
        (@CustomerID, 1, GETDATE(), DATEADD(DAY,5,GETDATE()), @StoreID, 1);

        SET @OrderID = SCOPE_IDENTITY();

        INSERT INTO sales.order_items
        (order_id, item_id, product_id, quantity, list_price, discount)
        SELECT
            @OrderID, 1, product_id, @Quantity, list_price, 0
        FROM production.products
        WHERE product_id = @ProductID;

        UPDATE production.stocks
        SET quantity = quantity - @Quantity
        WHERE store_id = @StoreID AND product_id = @ProductID;

        COMMIT;
        PRINT 'Order processed successfully';
    END TRY
    BEGIN CATCH
        ROLLBACK;
        PRINT 'Error processing order';
    END CATCH
END;
GO

/*==============================================================
16. Dynamic Product Search Procedure
==============================================================*/
CREATE OR ALTER PROCEDURE sp_SearchProducts
    @SearchName VARCHAR(100) = NULL,
    @CategoryID INT = NULL,
    @MinPrice DECIMAL(10,2) = NULL,
    @MaxPrice DECIMAL(10,2) = NULL,
    @SortColumn VARCHAR(50) = 'list_price'
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX) =
    'SELECT product_name, list_price FROM production.products WHERE 1=1';

    IF @SearchName IS NOT NULL
        SET @SQL += ' AND product_name LIKE ''%' + @SearchName + '%''';

    IF @CategoryID IS NOT NULL
        SET @SQL += ' AND category_id = ' + CAST(@CategoryID AS VARCHAR);

    IF @MinPrice IS NOT NULL
        SET @SQL += ' AND list_price >= ' + CAST(@MinPrice AS VARCHAR);

    IF @MaxPrice IS NOT NULL
        SET @SQL += ' AND list_price <= ' + CAST(@MaxPrice AS VARCHAR);

    SET @SQL += ' ORDER BY ' + @SortColumn;

    EXEC sp_executesql @SQL;
END;
GO

/*==============================================================
17. Staff Bonus Calculation System
==============================================================*/
DECLARE @StartDate DATE = '2024-01-01';
DECLARE @EndDate DATE = '2024-03-31';

SELECT
    s.staff_id,
    s.first_name,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS TotalSales,
    CASE
        WHEN SUM(oi.quantity * oi.list_price * (1 - oi.discount)) >= 50000 THEN '15%'
        WHEN SUM(oi.quantity * oi.list_price * (1 - oi.discount)) >= 25000 THEN '10%'
        ELSE '5%'
    END AS BonusRate
FROM sales.staffs s
JOIN sales.orders o ON s.staff_id = o.staff_id
JOIN sales.order_items oi ON o.order_id = oi.order_id
WHERE o.order_date BETWEEN @StartDate AND @EndDate
GROUP BY s.staff_id, s.first_name;

GO

/*==============================================================
18. Smart Inventory Management
==============================================================*/
DECLARE @CurrentQty INT;
DECLARE @CategoryID INT;

SELECT 
    @CurrentQty = s.quantity,
    @CategoryID = p.category_id
FROM production.stocks s
JOIN production.products p ON s.product_id = p.product_id
WHERE s.product_id = 1 AND s.store_id = 1;

IF @CurrentQty < 5
BEGIN
    IF @CategoryID IN (29,33,34)
        PRINT 'Critical athletic stock - reorder 30 units';
    ELSE
        PRINT 'Critical stock - reorder 20 units';
END
ELSE IF @CurrentQty BETWEEN 5 AND 15
    PRINT 'Moderate stock - reorder 10 units';
ELSE
    PRINT 'Stock level is sufficient';

GO

/*==============================================================
19. Customer Loyalty Tier Assignment
==============================================================*/
SELECT
    c.customer_id,
    c.first_name,
    ISNULL(SUM(oi.quantity * oi.list_price * (1 - oi.discount)),0) AS TotalSpent,
    CASE
        WHEN SUM(oi.quantity * oi.list_price * (1 - oi.discount)) IS NULL THEN 'No Orders'
        WHEN SUM(oi.quantity * oi.list_price * (1 - oi.discount)) >= 10000 THEN 'Platinum'
        WHEN SUM(oi.quantity * oi.list_price * (1 - oi.discount)) >= 5000 THEN 'Gold'
        WHEN SUM(oi.quantity * oi.list_price * (1 - oi.discount)) >= 2000 THEN 'Silver'
        ELSE 'Bronze'
    END AS LoyaltyTier
FROM sales.customers c
LEFT JOIN sales.orders o ON c.customer_id = o.customer_id
LEFT JOIN sales.order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.first_name;

GO

/*==============================================================
20. Product Lifecycle Management
==============================================================*/
CREATE OR ALTER PROCEDURE sp_DiscontinueProduct
    @ProductID INT,
    @ReplacementProductID INT = NULL
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM sales.orders o
        JOIN sales.order_items oi ON o.order_id = oi.order_id
        WHERE oi.product_id = @ProductID
          AND o.order_status IN (1,2)
    )
    BEGIN
        IF @ReplacementProductID IS NOT NULL
        BEGIN
            UPDATE sales.order_items
            SET product_id = @ReplacementProductID
            WHERE product_id = @ProductID;

            PRINT 'Pending orders updated with replacement product';
        END
        ELSE
        BEGIN
            PRINT 'Pending orders exist. Discontinuation aborted';
            RETURN;
        END
    END

    DELETE FROM production.stocks WHERE product_id = @ProductID;
    DELETE FROM production.products WHERE product_id = @ProductID;

    PRINT 'Product discontinued successfully';
END;
GO
