use ss13;
set autocommit = 0;
DELIMITER &&
CREATE PROCEDURE TransferSalary(p_emp_id INT)
BEGIN
    DECLARE v_salary DECIMAL(10,2);
    DECLARE v_balance DECIMAL(10,2);
    DECLARE v_bank_status INT;
    DECLARE emp_exists INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transaction Failed';
    END;
    -- Bắt đầu transaction
    START TRANSACTION;
    -- Kiểm tra xem nhân viên có tồn tại không
    SELECT COUNT(*) INTO emp_exists FROM employees WHERE emp_id = p_emp_id;
    IF emp_exists = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Employee does not exist';
    END IF;
    -- Lấy số dư quỹ công ty và lương nhân viên
    SELECT salary INTO v_salary FROM employees WHERE emp_id = p_emp_id LIMIT 1;
    SELECT balance INTO v_balance FROM company_funds LIMIT 1;
    -- Kiểm tra số dư quỹ công ty
    IF v_balance < v_salary THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough funds in company balance';
    END IF;
    -- Trừ tiền từ quỹ công ty
    UPDATE company_funds SET balance = balance - v_salary;
    -- Thêm bản ghi vào bảng payroll
    INSERT INTO payroll (emp_id, salary, pay_date) 
    VALUES (p_emp_id, v_salary, CURRENT_DATE);
    -- Kiểm tra trạng thái hệ thống ngân hàng (giả định)
    SET v_bank_status = FLOOR(RAND() * 2); -- 0 = lỗi, 1 = thành công
    IF v_bank_status = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Banking system error, transaction rolled back';
    ELSE
        COMMIT;
    END IF;
END &&
DELIMITER ;

-- Gọi Stored Procedure
CALL TransferSalary(1);
SELECT * FROM payroll;
SELECT * FROM company_funds;



