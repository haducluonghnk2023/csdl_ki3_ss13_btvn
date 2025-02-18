use ss13;
-- cau 2
create table `account` (
	acc_id int primary key auto_increment,
    emp_id int,
    bank_id int,
    amount_added decimal(15,2),
    total_amount decimal(15,2),
    foreign key (emp_id) references employees(emp_id),
    foreign key (bank_id) references bank(bank_id)
);
-- cau 3
INSERT INTO account (emp_id, bank_id, amount_added, total_amount) VALUES
(1, 1, 0.00, 12500.00),  
(2, 1, 0.00, 8900.00),   
(3, 1, 0.00, 10200.00),  
(4, 1, 0.00, 15000.00),  
(5, 1, 0.00, 7600.00);
-- cau 4
DELIMITER $$

CREATE PROCEDURE TransferSalaryAll()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE emp_id INT;
    DECLARE salary DECIMAL(15,2);
    DECLARE bank_id INT;
    DECLARE company_balance DECIMAL(15,2);
    DECLARE total_salary DECIMAL(15,2);
    DECLARE employee_cursor CURSOR FOR
        SELECT emp_id, salary, bank_id FROM employees;  -- Cần đảm bảo có cột 'salary' trong bảng employees
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Khởi tạo giao dịch
    DECLARE exit handler for sqlexception
    BEGIN
        -- Nếu có lỗi, rollback giao dịch và ghi log lỗi
        ROLLBACK;
        INSERT INTO transaction_log (log_message) VALUES ('Transaction failed: Database error');
    END;
    
    -- Bắt đầu giao dịch
    START TRANSACTION;

    -- Kiểm tra quỹ công ty có đủ tiền không
    SELECT balance INTO company_balance 
    FROM company_funds
    WHERE bank_id = 1;  -- Giả sử công ty có ngân hàng với bank_id = 1

    SELECT SUM(salary) INTO total_salary
    FROM employees;

    IF company_balance < total_salary THEN
        -- Nếu quỹ công ty không đủ, rollback và ghi log lỗi
        ROLLBACK;
        INSERT INTO transaction_log (log_message) VALUES ('Transaction failed: Insufficient company funds');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient company funds';
    END IF;

    -- Duyệt qua danh sách nhân viên và trả lương
    OPEN employee_cursor;
    
    read_loop: LOOP
        FETCH employee_cursor INTO emp_id, salary, bank_id;
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- Trừ số tiền lương khỏi quỹ công ty
        UPDATE company_funds
        SET balance = balance - salary
        WHERE bank_id = bank_id;

        -- Thêm bản ghi vào bảng payroll (Trigger sẽ kiểm tra trạng thái ngân hàng)
        INSERT INTO payroll (emp_id, salary_paid, payment_date) 
        VALUES (emp_id, salary, CURDATE());

        -- Cập nhật ngày trả lương trong bảng employees
        UPDATE employees
        SET last_pay_date = CURDATE()
        WHERE emp_id = emp_id;

        -- Cập nhật tài khoản nhân viên trong bảng account
        UPDATE account
        SET total_amount = total_amount + salary, 
            amount_added = salary
        WHERE emp_id = emp_id;

    END LOOP;
    
    CLOSE employee_cursor;

    -- Commit giao dịch nếu không có lỗi
    COMMIT;

    -- Ghi log số nhân viên đã nhận lương vào transaction_log
    INSERT INTO transaction_log (log_message) 
    VALUES (CONCAT('Salary paid to ', (SELECT COUNT(*) FROM employees), ' employees'));

END $$

DELIMITER ;
-- cau 5
CALL TransferSalaryAll();
SELECT * FROM company_funds;
SELECT * FROM payroll;
SELECT * FROM account;
SELECT * FROM transaction_log;



