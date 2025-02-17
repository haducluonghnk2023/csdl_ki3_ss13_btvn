use ss13;
create table accounts(
	account_id int primary key auto_increment,
    account_name varchar(50) ,
    balance decimal(10,2)
);
INSERT INTO accounts (account_name, balance) VALUES 
('Nguyễn Văn An', 1000.00),
('Trần Thị Bảy', 500.00);
-- cau 3
set autocommit = 0;
DELIMITER //
CREATE PROCEDURE TransferMoney(
    IN from_account INT,
    IN to_account INT,
    IN amount DECIMAL(10,2)
)
BEGIN
    DECLARE insufficient_balance INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
        BEGIN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transaction Failed';
        END;
    START TRANSACTION;
    -- Kiểm tra số dư tài khoản gửi
    IF (SELECT balance FROM accounts WHERE account_id = from_account) < amount THEN
        SET insufficient_balance = 1;
    END IF;
    -- Nếu số dư đủ, thực hiện giao dịch
    IF insufficient_balance = 0 THEN
        -- Trừ tiền từ tài khoản gửi
        UPDATE accounts 
        SET balance = balance - amount 
        WHERE account_id = from_account;
        -- Cộng tiền vào tài khoản nhận
        UPDATE accounts 
        SET balance = balance + amount 
        WHERE account_id = to_account;
        -- Xác nhận giao dịch
        COMMIT;
    ELSE
        -- Rollback nếu số dư không đủ
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient balance';
    END IF;
END //
DELIMITER ;
CALL TransferMoney(1, 2, 200.00);
SELECT * FROM accounts;
