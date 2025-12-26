USE StoreDB;
GO

/*==============================================================
1. Non-Clustered Index on sales.customers.email
==============================================================*/
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Customers_Email'
      AND object_id = OBJECT_ID('sales.customers')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Customers_Email
    ON sales.customers (email);
END;
GO

/*==============================================================
2. Composite Index on production.products (category_id, brand_id)
==============================================================*/
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Products_Category_Brand'
      AND object_id = OBJECT_ID('production.products')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Products_Category_Brand
    ON production.products (category_id, brand_id);
END;
GO

/*==============================================================
3. Index on sales.orders.order_date with included columns
==============================================================*/
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Orders_OrderDate'
      AND object_id = OBJECT_ID('sales.orders')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Orders_OrderDate
    ON sales.orders (order_date)
    INCLUDE (customer_id, store_id, order_status);
END;
GO

/*==============================================================
4. Trigger: Log new customer creation
==============================================================*/
CREATE OR ALTER TRIGGER trg_Log_NewCustomer
ON sales.customers
AFTER INSERT
AS
BEGIN
    INSERT INTO sales.customer_log (customer_id, action)
    SELECT customer_id, 'Welcome Customer'
    FROM inserted;
END;
GO

/*==============================================================
5. Trigger: Log product price changes
==============================================================*/
CREATE OR ALTER TRIGGER trg_Log_Product_Price_Change
ON production.products
AFTER UPDATE
AS
BEGIN
    IF UPDATE(list_price)
    BEGIN
        INSERT INTO production.price_history
        (product_id, old_price, new_price, change_date)
        SELECT
            d.product_id,
            d.list_price,
            i.list_price,
            GETDATE()
        FROM deleted d
        JOIN inserted i
            ON d.product_id = i.product_id
        WHERE d.list_price <> i.list_price;
    END
END;
GO

/*==============================================================
6. INSTEAD OF DELETE Trigger on production.categories
==============================================================*/
CREATE OR ALTER TRIGGER trg_Prevent_Category_Delete
ON production.categories
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM production.products p
        JOIN deleted d ON p.category_id = d.category_id
    )
    BEGIN
        RAISERROR(
            'Cannot delete category because it has associated products.',
            16, 1
        );
        RETURN;
    END

    DELETE FROM production.categories
    WHERE category_id IN (SELECT category_id FROM deleted);
END;
GO

/*==============================================================
7. Trigger: Reduce stock when order item inserted
==============================================================*/
CREATE OR ALTER TRIGGER trg_Update_Stock_On_OrderItem
ON sales.order_items
AFTER INSERT
AS
BEGIN
    UPDATE s
    SET s.quantity = s.quantity - i.quantity
    FROM production.stocks s
    JOIN inserted i ON s.product_id = i.product_id;
END;
GO

/*==============================================================
8. Trigger: Audit new orders
==============================================================*/
CREATE OR ALTER TRIGGER trg_Log_NewOrders
ON sales.orders
AFTER INSERT
AS
BEGIN
    INSERT INTO sales.order_audit
    (order_id, customer_id, store_id, staff_id, order_date)
    SELECT
        order_id,
        customer_id,
        store_id,
        staff_id,
        order_date
    FROM inserted;
END;
GO
