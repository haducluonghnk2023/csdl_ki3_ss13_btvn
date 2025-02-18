use ss13;
-- 2
CREATE TABLE course_fees (
    course_id INT PRIMARY KEY,
    fee DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE
);

CREATE TABLE student_wallets (
    student_id INT PRIMARY KEY,
    balance DECIMAL(10,2) NOT NULL DEFAULT 0,
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
);
-- 3
INSERT INTO course_fees (course_id, fee) VALUES
(1, 100.00),  -- Lập trình C: 100$
(2, 150.00);  -- Cơ sở dữ liệu: 150$

INSERT INTO student_wallets (student_id, balance) VALUES
(1, 200.00),  -- Nguyễn Văn An có 200$
(2, 50.00);   -- Trần Thị Ba chỉ có 50$
-- 4
CREATE TABLE enrollment_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT,
    course_id INT,
    status VARCHAR(50),
    log_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE
);
-- 5
drop procedure RegisterForCourse
DELIMITER //

CREATE PROCEDURE RegisterForCourse(
    IN p_student_name VARCHAR(50), 
    IN p_course_name VARCHAR(100)
)
BEGIN
    DECLARE v_student_id INT;
    DECLARE v_course_id INT;
    DECLARE v_balance DECIMAL(10,2);
    DECLARE v_fee DECIMAL(10,2);
    DECLARE v_available_seats INT;
    DECLARE v_error_message VARCHAR(255);

    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        INSERT INTO enrollment_history (student_id, course_id, status, log_time) 
        VALUES (v_student_id, v_course_id, v_error_message, NOW());
        ROLLBACK;
    END;

    -- Bắt đầu transaction
    START TRANSACTION;

    -- Kiểm tra sinh viên có tồn tại không
    SELECT student_id INTO v_student_id FROM students WHERE name = p_student_name;
    IF v_student_id IS NULL THEN
        SET v_error_message = 'FAILED: Student does not exist';
        INSERT INTO enrollment_history (status, log_time) VALUES (v_error_message, NOW());
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_message;
    END IF;

    -- Kiểm tra môn học có tồn tại không
    SELECT course_id INTO v_course_id FROM courses WHERE name = p_course_name;
    IF v_course_id IS NULL THEN
        SET v_error_message = 'FAILED: Course does not exist';
        INSERT INTO enrollment_history (student_id, status, log_time) VALUES (v_student_id, v_error_message, NOW());
        ROLLBACK;
     SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_message;
    END IF;

    -- Kiểm tra sinh viên đã đăng ký môn học chưa
    IF EXISTS (SELECT 1 FROM enrollments WHERE student_id = v_student_id AND course_id = v_course_id) THEN
        SET v_error_message = 'FAILED: Already enrolled';
        INSERT INTO enrollment_history (student_id, course_id, status, log_time) 
        VALUES (v_student_id, v_course_id, v_error_message, NOW());
        ROLLBACK;
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_message;
    END IF;

    -- Kiểm tra số chỗ trống của môn học
    SELECT available_seats INTO v_available_seats FROM courses WHERE course_id = v_course_id;
    IF v_available_seats <= 0 THEN
    SET v_error_message = 'FAILED: No available seats';
    INSERT INTO enrollment_history (student_id, course_id, status, log_time) 
    VALUES (v_student_id, v_course_id, v_error_message, NOW());
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_message;  -- Tạo lỗi và dừng thủ tục
	END IF;


    -- Lấy số dư tài khoản của sinh viên
    SELECT balance INTO v_balance FROM student_wallets WHERE student_id = v_student_id;
    
    -- Lấy học phí của môn học
    SELECT fee INTO v_fee FROM course_fees WHERE course_id = v_course_id;
    
    -- Kiểm tra số dư tài khoản của sinh viên có đủ tiền không
    IF v_balance < v_fee THEN
        SET v_error_message = 'FAILED: Insufficient balance';
        INSERT INTO enrollment_history (student_id, course_id, status, log_time) 
        VALUES (v_student_id, v_course_id, v_error_message, NOW());
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_message;
    END IF;

    -- Thực hiện đăng ký môn học
    INSERT INTO enrollments (student_id, course_id, enroll_date) VALUES (v_student_id, v_course_id, NOW());

    -- Trừ tiền từ tài khoản sinh viên
    UPDATE student_wallets SET balance = balance - v_fee WHERE student_id = v_student_id;

    -- Giảm số lượng chỗ trống của môn học
    UPDATE courses SET available_seats = available_seats - 1 WHERE course_id = v_course_id;

    -- Ghi nhận vào lịch sử đăng ký môn học
    INSERT INTO enrollment_history (student_id, course_id, status, log_time) 
    VALUES (v_student_id, v_course_id, 'REGISTERED', NOW());

    -- Commit transaction
    COMMIT;
END //

DELIMITER ;
-- 6
CALL RegisterForCourse('Nguyễn Văn An', 'Lập trình C'); 
CALL RegisterForCourse('Trần Thị Ba', 'Cơ sở dữ liệu'); 
CALL RegisterForCourse('Nguyễn Văn An', 'Cơ sở dữ liệu'); 
-- 7
SELECT * FROM student_wallets;
SELECT * FROM enrollment_history;
SELECT * FROM enrollments;
SELECT * FROM courses;
	