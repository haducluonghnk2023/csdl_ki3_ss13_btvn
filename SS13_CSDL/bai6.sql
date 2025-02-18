use ss13;
CREATE TABLE enrollments_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    student_name VARCHAR(50),
    course_name VARCHAR(100),
    status VARCHAR(50), -- 'Success' hoặc 'Failed'
    message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
set autocommit = 0;
DELIMITER $$
CREATE PROCEDURE RegisterCourse(
    IN p_student_name VARCHAR(50),
    IN p_course_name VARCHAR(100)
)
BEGIN
    DECLARE v_course_id INT;
    DECLARE v_student_id INT;
    DECLARE v_available_seats INT;
    DECLARE v_enrolled INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transaction Failed';
    END;
    START TRANSACTION;
    -- Kiểm tra sinh viên có tồn tại không
    SELECT student_id INTO v_student_id FROM students WHERE student_name = p_student_name LIMIT 1;
    IF v_student_id IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student not found';
    END IF;
    -- Kiểm tra môn học có tồn tại không
    SELECT course_id, available_seats INTO v_course_id, v_available_seats 
    FROM courses 
    WHERE course_name = p_course_name 
    LIMIT 1;
    IF v_course_id IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Course not found';
    END IF;
    -- Kiểm tra xem sinh viên đã đăng ký môn học này chưa
    SELECT COUNT(emrollment_id) INTO v_enrolled 
    FROM enrollments 
    WHERE student_id = v_student_id AND course_id = v_course_id;
    IF v_enrolled > 0 THEN
        -- Nếu đã đăng ký, rollback và ghi vào lịch sử
        INSERT INTO enrollments_history (student_name, course_name, status, message)
        VALUES (p_student_name, p_course_name, 'Failed', 'Student already enrolled in this course');
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student already enrolled';
    END IF;
    -- Kiểm tra xem môn học còn chỗ trống không
    IF v_available_seats > 0 THEN
        -- Thêm sinh viên vào bảng enrollments
        INSERT INTO enrollments (student_id, course_id) 
        VALUES (v_student_id, v_course_id);
        -- Cập nhật số chỗ trống
        UPDATE courses 
        SET available_seats = available_seats - 1 
        WHERE course_id = v_course_id;
        -- Ghi vào bảng enrollments_history
        INSERT INTO enrollments_history (student_name, course_name, status, message)
        VALUES (p_student_name, p_course_name, 'Success', 'Enrollment successful');
        -- Commit transaction
        COMMIT;
    ELSE
        -- Nếu không còn chỗ trống, ghi vào lịch sử và rollback
        INSERT INTO enrollments_history (student_name, course_name, status, message)
        VALUES (p_student_name, p_course_name, 'Failed', 'No available seats');
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No available seats';
    END IF;
END $$
DELIMITER ;
CALL RegisterCourse('Nguyễn Văn An', 'Cơ sở dữ liệu');
SELECT * FROM enrollments;
SELECT * FROM courses;
SELECT * FROM enrollments_history;

