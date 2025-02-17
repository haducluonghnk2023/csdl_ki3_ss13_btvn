use ss13;
CREATE TABLE products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(50),
    price DECIMAL(10,2),
    stock INT NOT NULL
);

CREATE TABLE orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    product_id INT,
    quantity INT NOT NULL,
    total_price DECIMAL(10,2),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

INSERT INTO products (product_name, price, stock) VALUES
('Laptop Dell', 1500.00, 10),
('iPhone 13', 1200.00, 8),
('Samsung TV', 800.00, 5),
('AirPods Pro', 250.00, 20),
('MacBook Air', 1300.00, 7);
set autocommit = 0;
DELIMITER //
CREATE PROCEDURE PlaceOrder(
    IN p_product_id INT,
    IN p_quantity INT
)
BEGIN
    DECLARE v_price DECIMAL(10,2);
    DECLARE v_stock INT;
    DECLARE v_total_price DECIMAL(10,2);
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transaction Failed';
    END;
    -- Bắt đầu transaction
    START TRANSACTION;
    -- Lấy thông tin số lượng tồn kho và giá sản phẩm
    SELECT price, stock INTO v_price, v_stock
    FROM products 
    WHERE product_id = p_product_id 
    LIMIT 1;
    -- Kiểm tra số lượng tồn kho có đủ không
    IF v_stock < p_quantity THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough stock';
    ELSE
        -- Tính tổng tiền
        SET v_total_price = v_price * p_quantity;
        -- Thêm đơn hàng mới vào bảng orders
        INSERT INTO orders (product_id, quantity, total_price)
        VALUES (p_product_id, p_quantity, v_total_price);
        -- Giảm số lượng tồn kho
        UPDATE products 
        SET stock = stock - p_quantity 
        WHERE product_id = p_product_id;
        COMMIT;
    END IF;
END //
DELIMITER ;

CALL PlaceOrder(2, 3);
SELECT * FROM orders;
SELECT * FROM products;


