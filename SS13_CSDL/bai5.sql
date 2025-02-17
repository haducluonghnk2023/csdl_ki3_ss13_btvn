create database ss13;
use ss13;
CREATE TABLE company_funds (
    fund_id INT PRIMARY KEY AUTO_INCREMENT,
    balance DECIMAL(15,2) NOT NULL -- Số dư quỹ công ty
);

CREATE TABLE employees (
    emp_id INT PRIMARY KEY AUTO_INCREMENT,
    emp_name VARCHAR(50) NOT NULL,   -- Tên nhân viên
    salary DECIMAL(10,2) NOT NULL    -- Lương nhân viên
);

CREATE TABLE payroll (
    payroll_id INT PRIMARY KEY AUTO_INCREMENT,
    emp_id INT,                      -- ID nhân viên (FK)
    salary DECIMAL(10,2) NOT NULL,   -- Lương được nhận
    pay_date DATE NOT NULL,          -- Ngày nhận lương
    FOREIGN KEY (emp_id) REFERENCES employees(emp_id)
);


INSERT INTO company_funds (balance) VALUES (50000.00);

INSERT INTO employees (emp_name, salary) VALUES
('Nguyễn Văn An', 5000.00),
('Trần Thị Bốn', 4000.00),
('Lê Văn Cường', 3500.00),
('Hoàng Thị Dung', 4500.00),
('Phạm Văn Em', 3800.00);
/*
	tạo bảng transaction_log 
    tạo procedure 
		input : employeeid, funid
        process :
			1 kiểm tra employeeid có tồn tại hay  không
				- sai --> ghi log bảng transaction_log và roll back lại
                - đúng -->kiểm tra số dư của công ty (company_fun) > salary(employee-->employeeid)
					- sai : ghi log transaction_log và rollback lại
                    - đúng :- trừ số dư của công ty trong bảng company_fun
							- ghi dữ liệu ra bảng payroll
                            - ghi log bảng transaction_log
                            - commit 
*/
create table transaction_log (
	log_id int primary key auto_increment,
    log_message text not null,
    log_time timestamp default current_timestamp
) engine = 'MyISAM';
drop procedure sendsalaryemployee ; 
alter table transaction_log
add column last_pay_date date;
set autocommit = 0;

DELIMITER $$
CREATE PROCEDURE sendsalaryemployee(
    IN employeeid INT,
    IN fundid INT
)
BEGIN
    DECLARE company_balance DECIMAL(10,2);
    DECLARE employee_salary DECIMAL(10,2);
    -- Kiểm tra xem nhân viên và quỹ công ty có tồn tại không
    IF NOT EXISTS (SELECT 1 FROM employees WHERE emp_id = employeeid) OR
       NOT EXISTS (SELECT 1 FROM company_funds WHERE fund_id = fundid) THEN
        INSERT INTO transaction_log(log_message)
        VALUES ('Mã nhân viên hoặc mã quỹ không tồn tại');
        ROLLBACK;
    ELSE
        -- Lấy số dư quỹ công ty và lương nhân viên
        SELECT balance INTO company_balance FROM company_funds WHERE fund_id = fundid;
        SELECT salary INTO employee_salary FROM employees WHERE emp_id = employeeid;
        -- Kiểm tra số dư có đủ để trả lương không
        IF company_balance >= employee_salary THEN
            -- Trừ tiền từ quỹ công ty
            UPDATE company_funds
            SET balance = balance - employee_salary
            WHERE fund_id = fundid;
            -- Ghi log
            INSERT INTO transaction_log(log_message)
            VALUES ('Thanh toán lương thành công');
            -- Thêm vào bảng payroll
            INSERT INTO payroll (emp_id, salary, pay_date) 
            VALUES (employeeid, employee_salary, CURRENT_DATE);
            COMMIT;
        ELSE
            INSERT INTO transaction_log(log_message)
            VALUES ('Số dư tài khoản không đủ');
            ROLLBACK;
        END IF;
    END IF;
END$$
DELIMITER ;


select * from company_funds;
select * from employees;
select * from transaction_log;
select * from payroll;

call sendsalaryemployee(1,1);