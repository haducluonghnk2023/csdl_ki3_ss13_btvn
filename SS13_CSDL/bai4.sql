use ss13;
CREATE TABLE students (
    student_id INT PRIMARY KEY AUTO_INCREMENT,
    student_name VARCHAR(50)
);

CREATE TABLE courses (
    course_id INT PRIMARY KEY AUTO_INCREMENT,
    course_name VARCHAR(100),
    available_seats INT NOT NULL
);	

CREATE TABLE enrollments (
    enrollment_id INT PRIMARY KEY AUTO_INCREMENT,
    student_id INT,
    course_id INT,
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (course_id) REFERENCES courses(course_id)
);
INSERT INTO students (student_name) VALUES ('Nguyễn Văn An'), ('Trần Thị Ba');

INSERT INTO courses (course_name, available_seats) VALUES 
('Lập trình C', 25), 
('Cơ sở dữ liệu', 22);
set autocommit = 0;
DELIMITER //
CREATE PROCEDURE EnrollStudent(
    IN p_student_name VARCHAR(50),
    IN p_course_name VARCHAR(100)
)
BEGIN
    DECLARE v_student_id INT;
    DECLARE v_course_id INT;
    DECLARE v_available_seats INT;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transaction Failed';
    END;
    START TRANSACTION;
    -- Lấy student_id dựa trên tên sinh viên
    SELECT student_id INTO v_student_id 
    FROM students 
    WHERE student_name = p_student_name 
    LIMIT 1;
    -- Lấy course_id và số chỗ trống dựa trên tên môn học
    SELECT course_id, available_seats INTO v_course_id, v_available_seats 
    FROM courses 
    WHERE course_name = p_course_name 
    LIMIT 1;
    -- Kiểm tra xem môn học còn chỗ trống không
    IF v_available_seats > 0 THEN
        -- Thêm vào bảng enrollments
        INSERT INTO enrollments (student_id, course_id) 
        VALUES (v_student_id, v_course_id);
        -- Giảm số chỗ trống của môn học đi 1
        UPDATE courses 
        SET available_seats = available_seats - 1 
        WHERE course_id = v_course_id;
        -- Xác nhận transaction
        COMMIT;
    ELSE
        -- Nếu không còn chỗ, rollback transaction
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No available seats';
    END IF;
END //

DELIMITER ;
CALL EnrollStudent('Nguyễn Văn An', 'Lập trình C');
SELECT e.enrollment_id, s.student_name, c.course_name 
FROM enrollments e
JOIN students s ON e.student_id = s.student_id
JOIN courses c ON e.course_id = c.course_id;
SELECT * FROM courses;




