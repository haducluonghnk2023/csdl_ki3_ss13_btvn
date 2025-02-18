-- cau 2
create table bank(
	bank_id int primary key auto_increment,
    bank_name varchar(255) not null,
    status enum('active','error') not null default 'active'
);
-- cau 3
INSERT INTO bank (bank_id, bank_name, status) VALUES 
(1,'VietinBank', 'ACTIVE'),   
(2,'Sacombank', 'ERROR'),    
(3, 'Agribank', 'ACTIVE');   
-- cau 4
alter table company_funds 
add column bank_id int,
add constraint fk_bank foreign key (bank_id) references bank(bank_id);
-- cau 5
UPDATE company_funds SET bank_id = 1 WHERE balance = 50000.00;
INSERT INTO company_funds (balance, bank_id) VALUES (45000.00,2);
-- cau 6
DELIMITER $$
CREATE TRIGGER CheckBankStatus
BEFORE INSERT ON payroll
FOR EACH ROW
BEGIN
    DECLARE bank_status ENUM('active', 'error');
    -- Lấy trạng thái của ngân hàng đang được sử dụng
    SELECT status INTO bank_status
    FROM bank
    WHERE bank_id = (SELECT bank_id FROM company_funds WHERE bank_id IS NOT NULL LIMIT 1);
    -- Nếu ngân hàng có trạng thái "ERROR", báo lỗi và ngừng chèn vào bảng payroll
    IF bank_status = 'ERROR' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ngân hàng gặp sự cố. Không thể thực hiện trả lương.';
    END IF;
END $$
DELIMITER ;
-- cau 7
drop procedure TransferSalary;
DELIMITER $$
CREATE PROCEDURE TransferSalary(
    IN p_emp_id INT, -- ID của nhân viên nhận lương
    IN p_salary DECIMAL(10,2) -- Số tiền lương cần chuyển
)
BEGIN
    DECLARE company_balance DECIMAL(10,2);
    DECLARE emp_exists INT;
    DECLARE bank_status ENUM('active', 'error');
    -- Khởi tạo giao dịch
    DECLARE exit handler for sqlexception
    BEGIN
        -- Nếu có lỗi xảy ra, rollback giao dịch
        ROLLBACK;
        INSERT INTO transaction_log (log_message) VALUES ('Lỗi trong giao dịch chuyển lương. Rollback đã được thực hiện.');
    END;
    -- Bắt đầu giao dịch
    START TRANSACTION;
    -- Kiểm tra số dư quỹ công ty
    SELECT balance INTO company_balance FROM company_funds WHERE bank_id IS NOT NULL LIMIT 1;
    -- Kiểm tra nhân viên có tồn tại không
    SELECT COUNT(*) INTO emp_exists FROM employees WHERE employee_id = p_emp_id;
    IF emp_exists = 0 THEN
        -- Nếu nhân viên không tồn tại, rollback và ghi log lỗi
        ROLLBACK;
        INSERT INTO transaction_log (log_message) VALUES ('Nhân viên không tồn tại. Rollback đã được thực hiện.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nhân viên không tồn tại';
    END IF;
    -- Kiểm tra trạng thái ngân hàng (được kiểm tra qua trigger CheckBankStatus)
    -- Nếu ngân hàng có trạng thái "ERROR", rollback và ghi log lỗi
    SELECT status INTO bank_status
    FROM bank
    WHERE bank_id = (SELECT bank_id FROM company_funds WHERE bank_id IS NOT NULL LIMIT 1);
    IF bank_status = 'ERROR' THEN
        ROLLBACK;
        INSERT INTO transaction_log (log_message) VALUES ('Ngân hàng gặp sự cố. Rollback đã được thực hiện.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ngân hàng gặp sự cố';
    END IF;
    -- Kiểm tra quỹ công ty có đủ để trả lương không
    IF company_balance < p_salary THEN
        -- Nếu quỹ không đủ tiền, rollback và ghi log lỗi
        ROLLBACK;
        INSERT INTO transaction_log (log_message) VALUES ('Quỹ công ty không đủ để trả lương. Rollback đã được thực hiện.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quỹ công ty không đủ tiền để trả lương';
    END IF;
    -- Cập nhật số dư quỹ công ty sau khi trả lương
    UPDATE company_funds SET balance = balance - p_salary WHERE bank_id IS NOT NULL LIMIT 1;
    -- Thêm bản ghi vào bảng payroll để xác nhận lương đã được trả
    INSERT INTO payroll (employee_id, salary_amount, payment_date)
    VALUES (p_emp_id, p_salary, NOW());
    -- Cập nhật ngày trả lương trong bảng employees
    UPDATE employees SET last_pay_date = NOW() WHERE employee_id = p_emp_id;
    -- Commit giao dịch nếu mọi thứ đều thành công
    COMMIT;
    INSERT INTO transaction_log (log_message) VALUES ('Chuyển lương thành công cho nhân viên ' || p_emp_id);
END $$
DELIMITER ;
-- cau 8
CALL TransferSalary(1, 10000.00);
select * from transaction_log;

