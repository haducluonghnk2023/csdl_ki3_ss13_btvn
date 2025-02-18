use ss13;
create table student_status (
	student_id int primary key auto_increment,
    status enum('Active','Graduate','Supened'),
    foreign key (student_id) references students(student_id)
);
INSERT INTO student_status (student_id, status) VALUES
(1, 'ACTIVE'),
(2, 'GRADUATED');
select * from student_status
-- cau 3
drop procedure RegisterCourse
DELIMITER $$
CREATE PROCEDURE RegisterCourse(
    IN p_student_name VARCHAR(50),
    IN p_course_name VARCHAR(100)
)
BEGIN
    DECLARE student_exists INT;
    DECLARE course_exists INT;
    DECLARE available_seats INT;
    DECLARE student_status ENUM('Active', 'Graduate', 'Suspended');
    DECLARE student_id INT;
    DECLARE course_id INT;
    -- Khởi tạo giao dịch
    DECLARE exit handler for sqlexception
    BEGIN
        -- Nếu có lỗi, rollback giao dịch và ghi log vào bảng enrollment_history
        ROLLBACK;
        INSERT INTO enrollments_history (student_name, course_name, status) 
        VALUES (p_student_name, p_course_name, 'FAILED: Database error');
    END;
    -- Bắt đầu giao dịch
    START TRANSACTION;
    -- Kiểm tra sinh viên có tồn tại không
    SELECT student_id INTO student_id
    FROM students
    WHERE student_name = p_student_name;
    IF student_id IS NULL THEN
        -- Nếu sinh viên không tồn tại, rollback và ghi log lỗi
        ROLLBACK;
        INSERT INTO enrollments_history (student_name, course_name, status) 
        VALUES (p_student_name, p_course_name, 'FAILED: Student does not exist');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student does not exist';
    END IF;
    -- Kiểm tra trạng thái sinh viên
    SELECT status INTO student_status FROM student_status WHERE student_id = student_id;
    IF student_status = 'GRADUATED' OR student_status = 'SUSPENDED' THEN
        -- Nếu sinh viên đã tốt nghiệp hoặc bị đình chỉ, rollback và ghi log lỗi
        ROLLBACK;
        INSERT INTO enrollments_history (student_name, course_name, status) 
        VALUES (p_student_name, p_course_name, 'FAILED: Student not eligible');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student not eligible';
    END IF;
    -- Kiểm tra môn học có tồn tại không
    SELECT course_id INTO course_id
    FROM courses
    WHERE course_name = p_course_name;
    IF course_id IS NULL THEN
        -- Nếu môn học không tồn tại, rollback và ghi log lỗi
        ROLLBACK;
        INSERT INTO enrollments_history (student_name, course_name, status) 
        VALUES (p_student_name, p_course_name, 'FAILED: Course does not exist');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Course does not exist';
    END IF;
    -- Kiểm tra sinh viên đã đăng ký môn học này chưa
    IF EXISTS (SELECT 1 FROM enrollments WHERE student_id = student_id AND course_id = course_id) THEN
        -- Nếu đã đăng ký, rollback và ghi log lỗi
        ROLLBACK;
        INSERT INTO enrollments_history (student_name, course_name, status) 
        VALUES (p_student_name, p_course_name, 'FAILED: Already enrolled');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Already enrolled';
    END IF;
    -- Kiểm tra số chỗ trống của môn học
    SELECT available_seats INTO available_seats
    FROM courses
    WHERE course_id = course_id;
    IF available_seats <= 0 THEN
        -- Nếu không còn chỗ trống, rollback và ghi log lỗi
        ROLLBACK;
        INSERT INTO enrollments_history (student_name, course_name, status) 
        VALUES (p_student_name, p_course_name, 'FAILED: No available seats');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No available seats';
    END IF;
    -- Thêm sinh viên vào bảng enrollments
    INSERT INTO enrollments (student_id, course_id) 
    VALUES (student_id, course_id);
    -- Cập nhật số chỗ trống của môn học
    UPDATE courses SET available_seats = available_seats - 1 WHERE course_id = course_id;
    -- Ghi lại lịch sử đăng ký vào bảng enrollment_history
    INSERT INTO enrollments_history (student_name, course_name, status) 
    VALUES (p_student_name, p_course_name, 'REGISTERED');
    -- Commit giao dịch nếu mọi thứ đều thành công
    COMMIT;
END $$
DELIMITER ;
-- cau 4
CALL RegisterCourse('John Doe', 'Mathematics');
SELECT * FROM enrollments;
SELECT * FROM courses;
SELECT * FROM enrollments_history;
