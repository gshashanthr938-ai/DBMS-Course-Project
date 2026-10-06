-- Campus Ledger: complete MySQL 8 presentation database.
-- Run on a NEW MySQL server/database. Do not run against a real college database.
-- The sample rows are synthetic. Run this file once, then execute Live_Demo_Queries.sql.
CREATE DATABASE college_pbl_presentation CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE college_pbl_presentation;


-- ===== 01_schema.sql =====
-- MySQL 8.0.16+ | InnoDB | utf8mb4 | All names are case-consistent.
CREATE TABLE department (
 department_id INT AUTO_INCREMENT PRIMARY KEY,
 department_code VARCHAR(12) NOT NULL UNIQUE,
 department_name VARCHAR(120) NOT NULL
);
CREATE TABLE programme (
 programme_id INT AUTO_INCREMENT PRIMARY KEY,
 department_id INT NOT NULL,
 programme_code VARCHAR(20) NOT NULL UNIQUE,
 programme_name VARCHAR(120) NOT NULL,
 duration_terms INT NOT NULL CHECK(duration_terms BETWEEN 1 AND 16),
 FOREIGN KEY(department_id) REFERENCES department(department_id)
);
CREATE TABLE course (
 course_id INT AUTO_INCREMENT PRIMARY KEY,
 department_id INT NOT NULL,
 course_code VARCHAR(20) NOT NULL UNIQUE,
 course_title VARCHAR(150) NOT NULL,
 credits DECIMAL(3,1) NOT NULL CHECK(credits>0 AND credits<=10),
 FOREIGN KEY(department_id) REFERENCES department(department_id)
);
CREATE TABLE faculty (
 faculty_id INT AUTO_INCREMENT PRIMARY KEY,
 department_id INT NOT NULL,
 employee_no VARCHAR(20) NOT NULL UNIQUE,
 full_name VARCHAR(100) NOT NULL,
 email VARCHAR(120), phone VARCHAR(20),
 FOREIGN KEY(department_id) REFERENCES department(department_id)
);
CREATE TABLE semester (
 semester_id INT AUTO_INCREMENT PRIMARY KEY,
 academic_year VARCHAR(12) NOT NULL,
 term_name VARCHAR(20) NOT NULL,
 start_date DATE NOT NULL, end_date DATE NOT NULL,
 UNIQUE(academic_year,term_name), CHECK(start_date<end_date)
);
CREATE TABLE student (
 student_id INT AUTO_INCREMENT PRIMARY KEY,
 programme_id INT NOT NULL,
 registration_no VARCHAR(24) NOT NULL UNIQUE,
 full_name VARCHAR(100) NOT NULL,
 date_of_birth DATE NOT NULL,
 email VARCHAR(120), phone VARCHAR(20),
 admission_date DATE NOT NULL,
 student_status VARCHAR(12) NOT NULL DEFAULT 'ACTIVE',
 CHECK(student_status IN ('ACTIVE','GRADUATED','WITHDRAWN')),
 CHECK(date_of_birth<admission_date),
 FOREIGN KEY(programme_id) REFERENCES programme(programme_id),
 INDEX idx_student_name(full_name)
);
CREATE TABLE guardian (
 guardian_id INT AUTO_INCREMENT PRIMARY KEY,
 full_name VARCHAR(100) NOT NULL, phone VARCHAR(20) NOT NULL, email VARCHAR(120)
);
CREATE TABLE student_guardian (
 student_id INT NOT NULL, guardian_id INT NOT NULL,
 relationship_type VARCHAR(30) NOT NULL,
 PRIMARY KEY(student_id,guardian_id),
 FOREIGN KEY(student_id) REFERENCES student(student_id),
 FOREIGN KEY(guardian_id) REFERENCES guardian(guardian_id)
);
CREATE TABLE programme_course (
 programme_id INT NOT NULL, course_id INT NOT NULL,
 recommended_term INT NOT NULL CHECK(recommended_term>0),
 course_type VARCHAR(10) NOT NULL CHECK(course_type IN ('CORE','ELECTIVE')),
 PRIMARY KEY(programme_id,course_id),
 FOREIGN KEY(programme_id) REFERENCES programme(programme_id),
 FOREIGN KEY(course_id) REFERENCES course(course_id)
);
CREATE TABLE course_offering (
 offering_id INT AUTO_INCREMENT PRIMARY KEY,
 course_id INT NOT NULL, semester_id INT NOT NULL, faculty_id INT NOT NULL,
 section_code VARCHAR(12) NOT NULL,
 capacity INT NOT NULL CHECK(capacity BETWEEN 1 AND 500),
 UNIQUE(course_id,semester_id,section_code),
 FOREIGN KEY(course_id) REFERENCES course(course_id),
 FOREIGN KEY(semester_id) REFERENCES semester(semester_id),
 FOREIGN KEY(faculty_id) REFERENCES faculty(faculty_id)
);
CREATE TABLE registration (
 registration_id INT AUTO_INCREMENT PRIMARY KEY,
 student_id INT NOT NULL, offering_id INT NOT NULL,
 registered_on DATE NOT NULL,
 registration_status VARCHAR(10) NOT NULL DEFAULT 'ACTIVE', dropped_on DATE,
 UNIQUE(student_id,offering_id),
 CHECK((registration_status='ACTIVE' AND dropped_on IS NULL) OR
       (registration_status='DROPPED' AND dropped_on>=registered_on)),
 FOREIGN KEY(student_id) REFERENCES student(student_id),
 FOREIGN KEY(offering_id) REFERENCES course_offering(offering_id),
 INDEX idx_registration_roster(offering_id,registration_status)
);
CREATE TABLE class_session (
 session_id INT AUTO_INCREMENT PRIMARY KEY, offering_id INT NOT NULL,
 session_date DATE NOT NULL, session_no INT NOT NULL CHECK(session_no>0),
 topic VARCHAR(200), UNIQUE(offering_id,session_date,session_no),
 FOREIGN KEY(offering_id) REFERENCES course_offering(offering_id)
);
CREATE TABLE attendance (
 registration_id INT NOT NULL, session_id INT NOT NULL,
 attendance_status VARCHAR(8) NOT NULL CHECK(attendance_status IN ('PRESENT','ABSENT')),
 PRIMARY KEY(registration_id,session_id),
 FOREIGN KEY(registration_id) REFERENCES registration(registration_id),
 FOREIGN KEY(session_id) REFERENCES class_session(session_id)
);
CREATE TABLE examination (
 exam_id INT AUTO_INCREMENT PRIMARY KEY, offering_id INT NOT NULL,
 exam_name VARCHAR(60) NOT NULL, exam_date DATE NOT NULL,
 max_marks DECIMAL(6,2) NOT NULL CHECK(max_marks>0 AND max_marks<=1000),
 weight_percent DECIMAL(5,2) NOT NULL CHECK(weight_percent>0 AND weight_percent<=100),
 UNIQUE(offering_id,exam_name),
 FOREIGN KEY(offering_id) REFERENCES course_offering(offering_id)
);
CREATE TABLE exam_result (
 registration_id INT NOT NULL, exam_id INT NOT NULL,
 result_status VARCHAR(8) NOT NULL, marks_obtained DECIMAL(6,2),
 PRIMARY KEY(registration_id,exam_id),
 CHECK((result_status='SCORED' AND marks_obtained IS NOT NULL AND marks_obtained>=0) OR
       (result_status='ABSENT' AND marks_obtained IS NULL)),
 FOREIGN KEY(registration_id) REFERENCES registration(registration_id),
 FOREIGN KEY(exam_id) REFERENCES examination(exam_id)
);
CREATE TABLE grade_scale (
 letter_grade VARCHAR(3) PRIMARY KEY,
 minimum_score DECIMAL(5,2) NOT NULL UNIQUE CHECK(minimum_score BETWEEN 0 AND 100),
 grade_points DECIMAL(3,1) NOT NULL CHECK(grade_points BETWEEN 0 AND 10)
);
CREATE TABLE grade (
 registration_id INT PRIMARY KEY,
 letter_grade VARCHAR(3) NOT NULL,
 finalized_on DATE NOT NULL,
 FOREIGN KEY(registration_id) REFERENCES registration(registration_id),
 FOREIGN KEY(letter_grade) REFERENCES grade_scale(letter_grade)
);
CREATE TABLE fee_bill (
 bill_id INT AUTO_INCREMENT PRIMARY KEY,
 student_id INT NOT NULL, semester_id INT NOT NULL,
 bill_no VARCHAR(32) NOT NULL UNIQUE, description VARCHAR(150) NOT NULL,
 issued_on DATE NOT NULL, due_date DATE NOT NULL,
 total_amount DECIMAL(12,2) NOT NULL CHECK(total_amount>0),
 CHECK(due_date>=issued_on),
 FOREIGN KEY(student_id) REFERENCES student(student_id),
 FOREIGN KEY(semester_id) REFERENCES semester(semester_id),
 INDEX idx_bill_due(due_date)
);
CREATE TABLE payment (
 payment_id INT AUTO_INCREMENT PRIMARY KEY, bill_id INT NOT NULL,
 receipt_no VARCHAR(40) NOT NULL UNIQUE,
 paid_on DATE NOT NULL, amount DECIMAL(12,2) NOT NULL CHECK(amount>0),
 payment_mode VARCHAR(16) NOT NULL,
 transaction_reference VARCHAR(100),
 CHECK(payment_mode IN ('CASH','UPI','BANK_TRANSFER')),
 CHECK(payment_mode='CASH' OR (transaction_reference IS NOT NULL AND LENGTH(TRIM(transaction_reference))>0)),
 FOREIGN KEY(bill_id) REFERENCES fee_bill(bill_id)
);
CREATE TABLE app_user (
 user_id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(60) NOT NULL UNIQUE,
 password_hash VARCHAR(255) NOT NULL,
 role VARCHAR(12) NOT NULL CHECK(role IN ('ADMIN','FACULTY','EXAMS','ACCOUNTS','STUDENT','HOD')),
 student_id INT UNIQUE, faculty_id INT UNIQUE, department_id INT,
 CHECK((role='STUDENT' AND student_id IS NOT NULL AND faculty_id IS NULL AND department_id IS NULL)
 OR (role='FACULTY' AND faculty_id IS NOT NULL AND student_id IS NULL AND department_id IS NULL)
 OR (role='HOD' AND department_id IS NOT NULL AND student_id IS NULL AND faculty_id IS NULL)
 OR (role IN ('ADMIN','EXAMS','ACCOUNTS') AND student_id IS NULL AND faculty_id IS NULL AND department_id IS NULL)),
 FOREIGN KEY(student_id) REFERENCES student(student_id),
 FOREIGN KEY(faculty_id) REFERENCES faculty(faculty_id),
 FOREIGN KEY(department_id) REFERENCES department(department_id)
);
CREATE TABLE audit_event (
 event_id INT AUTO_INCREMENT PRIMARY KEY, user_id INT,
 action VARCHAR(60) NOT NULL, detail VARCHAR(255) NOT NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY(user_id) REFERENCES app_user(user_id)
);


-- ===== 02_routines.sql =====
-- Protected mutations use definer procedures. The web DB account receives EXECUTE,
-- not INSERT/UPDATE/DELETE on registration or payment. All calls are top-level.
DELIMITER $$
CREATE PROCEDURE register_student(IN p_student INT, IN p_offering INT, IN p_date DATE)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_programme INT DEFAULT NULL;
 DECLARE v_status VARCHAR(12);
 DECLARE v_course INT; DECLARE v_sem INT; DECLARE v_capacity INT;
 DECLARE v_start DATE; DECLARE v_end DATE;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
 START TRANSACTION;
 SELECT programme_id,student_status INTO v_programme,v_status FROM student WHERE student_id=p_student FOR UPDATE;
 IF v_programme IS NULL OR v_status<>'ACTIVE' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Select an active student'; END IF;
 SELECT course_id,semester_id,capacity INTO v_course,v_sem,v_capacity FROM course_offering WHERE offering_id=p_offering FOR UPDATE;
 IF v_course IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Course offering does not exist'; END IF;
 SELECT start_date,end_date INTO v_start,v_end FROM semester WHERE semester_id=v_sem;
 IF p_date IS NULL OR p_date<v_start OR p_date>v_end OR p_date>CURRENT_DATE THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registration date must be within the semester and not in the future'; END IF;
 IF NOT EXISTS(SELECT 1 FROM programme_course WHERE programme_id=v_programme AND course_id=v_course) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Course is not in the student programme'; END IF;
 IF EXISTS(SELECT 1 FROM registration r JOIN course_offering o ON o.offering_id=r.offering_id WHERE r.student_id=p_student AND o.course_id=v_course AND o.semester_id=v_sem) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Student already registered for this course and semester'; END IF;
 IF (SELECT COUNT(*) FROM registration WHERE offering_id=p_offering AND registration_status='ACTIVE')>=v_capacity THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Section is full'; END IF;
 INSERT INTO registration(student_id,offering_id,registered_on) VALUES(p_student,p_offering,p_date);
 COMMIT;
END$$
CREATE PROCEDURE drop_registration(IN p_registration INT, IN p_date DATE)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_offering INT; DECLARE v_dummy INT; DECLARE v_date DATE;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
 START TRANSACTION;
 SELECT offering_id INTO v_offering FROM registration WHERE registration_id=p_registration;
 SELECT offering_id INTO v_dummy FROM course_offering WHERE offering_id=v_offering FOR UPDATE;
 SELECT registered_on INTO v_date FROM registration WHERE registration_id=p_registration FOR UPDATE;
 IF v_date IS NULL OR p_date<v_date OR p_date>CURRENT_DATE THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid drop date'; END IF;
 IF EXISTS(SELECT 1 FROM grade WHERE registration_id=p_registration) OR EXISTS(SELECT 1 FROM exam_result WHERE registration_id=p_registration) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cannot drop a registration with examination results'; END IF;
 IF EXISTS(SELECT 1 FROM attendance a JOIN class_session s ON s.session_id=a.session_id WHERE a.registration_id=p_registration AND s.session_date>=p_date) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Drop date would invalidate recorded attendance'; END IF;
 UPDATE registration SET registration_status='DROPPED',dropped_on=p_date WHERE registration_id=p_registration AND registration_status='ACTIVE';
 COMMIT;
END$$
CREATE PROCEDURE collect_payment(IN p_bill INT,IN p_receipt VARCHAR(40),IN p_date DATE,IN p_amount DECIMAL(12,2),IN p_mode VARCHAR(16),IN p_ref VARCHAR(100))
SQL SECURITY DEFINER
BEGIN
 DECLARE v_total DECIMAL(12,2); DECLARE v_paid DECIMAL(12,2); DECLARE v_issued DATE;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
 START TRANSACTION;
 SELECT total_amount,issued_on INTO v_total,v_issued FROM fee_bill WHERE bill_id=p_bill FOR UPDATE;
 IF v_total IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Bill does not exist'; END IF;
 SELECT COALESCE(SUM(amount),0) INTO v_paid FROM payment WHERE bill_id=p_bill;
 IF p_amount IS NULL OR p_amount<=0 OR p_amount>v_total-v_paid THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Payment must be positive and no more than the remaining balance'; END IF;
 IF p_date IS NULL OR p_date<v_issued OR p_date>CURRENT_DATE THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Payment date must be between bill issue and today'; END IF;
 IF p_receipt IS NULL OR LENGTH(TRIM(p_receipt))=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Receipt number is required'; END IF;
 INSERT INTO payment(bill_id,receipt_no,paid_on,amount,payment_mode,transaction_reference) VALUES(p_bill,p_receipt,p_date,p_amount,p_mode,NULLIF(TRIM(p_ref),''));
 COMMIT;
END$$
CREATE PROCEDURE validate_attendance(IN p_reg INT, IN p_session INT)
BEGIN
 IF NOT EXISTS(SELECT 1 FROM registration r JOIN class_session s ON s.offering_id=r.offering_id WHERE r.registration_id=p_reg AND s.session_id=p_session AND s.session_date>=r.registered_on AND (r.dropped_on IS NULL OR s.session_date<r.dropped_on)) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Session and registration must match and be within active registration dates'; END IF;
END$$
CREATE TRIGGER attendance_insert BEFORE INSERT ON attendance FOR EACH ROW
BEGIN CALL validate_attendance(NEW.registration_id,NEW.session_id); END$$
CREATE TRIGGER attendance_update BEFORE UPDATE ON attendance FOR EACH ROW
BEGIN CALL validate_attendance(NEW.registration_id,NEW.session_id); END$$
CREATE PROCEDURE validate_result(IN p_reg INT,IN p_exam INT,IN p_marks DECIMAL(6,2))
BEGIN
 IF NOT EXISTS(SELECT 1 FROM registration r JOIN examination e ON e.offering_id=r.offering_id WHERE r.registration_id=p_reg AND e.exam_id=p_exam AND r.registration_status='ACTIVE' AND (p_marks IS NULL OR p_marks<=e.max_marks)) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Result must match an active registration and marks cannot exceed the maximum'; END IF;
 IF EXISTS(SELECT 1 FROM grade WHERE registration_id=p_reg) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Reopen the final grade before changing results'; END IF;
END$$
CREATE TRIGGER result_insert BEFORE INSERT ON exam_result FOR EACH ROW
BEGIN CALL validate_result(NEW.registration_id,NEW.exam_id,NEW.marks_obtained); END$$
CREATE TRIGGER result_update BEFORE UPDATE ON exam_result FOR EACH ROW
BEGIN CALL validate_result(NEW.registration_id,NEW.exam_id,NEW.marks_obtained); END$$
CREATE TRIGGER result_delete BEFORE DELETE ON exam_result FOR EACH ROW
BEGIN IF EXISTS(SELECT 1 FROM grade WHERE registration_id=OLD.registration_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Reopen the final grade before deleting results'; END IF; END$$
CREATE TRIGGER session_insert BEFORE INSERT ON class_session FOR EACH ROW
BEGIN
 IF NEW.session_date>CURRENT_DATE OR NOT EXISTS(SELECT 1 FROM course_offering o JOIN semester s ON s.semester_id=o.semester_id WHERE o.offering_id=NEW.offering_id AND NEW.session_date BETWEEN s.start_date AND s.end_date) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Held session date must be within the semester and not in the future'; END IF;
END$$
CREATE TRIGGER session_update BEFORE UPDATE ON class_session FOR EACH ROW
BEGIN
 IF NEW.offering_id<>OLD.offering_id OR NEW.session_date<>OLD.session_date OR NEW.session_no<>OLD.session_no THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Session identity is immutable; delete an unused session and recreate it'; END IF;
END$$
CREATE TRIGGER examination_insert BEFORE INSERT ON examination FOR EACH ROW
BEGIN
 IF NOT EXISTS(SELECT 1 FROM course_offering o JOIN semester s ON s.semester_id=o.semester_id WHERE o.offering_id=NEW.offering_id AND NEW.exam_date BETWEEN s.start_date AND s.end_date) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Exam date must be within the semester'; END IF;
 IF EXISTS(SELECT 1 FROM grade g JOIN registration r ON r.registration_id=g.registration_id WHERE r.offering_id=NEW.offering_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Reopen all final grades before adding an examination'; END IF;
END$$
CREATE TRIGGER examination_update BEFORE UPDATE ON examination FOR EACH ROW
BEGIN
 IF EXISTS(SELECT 1 FROM exam_result WHERE exam_id=OLD.exam_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='An examination with results cannot be edited'; END IF;
 IF NOT EXISTS(SELECT 1 FROM course_offering o JOIN semester s ON s.semester_id=o.semester_id WHERE o.offering_id=NEW.offering_id AND NEW.exam_date BETWEEN s.start_date AND s.end_date) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Exam date must be within the semester'; END IF;
END$$
CREATE TRIGGER offering_update BEFORE UPDATE ON course_offering FOR EACH ROW
BEGIN
 IF NEW.course_id<>OLD.course_id OR NEW.semester_id<>OLD.semester_id THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Course and semester of an offering are immutable'; END IF;
 IF NEW.capacity<(SELECT COUNT(*) FROM registration WHERE offering_id=OLD.offering_id AND registration_status='ACTIVE') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Capacity cannot be lower than active enrolment'; END IF;
END$$
CREATE TRIGGER student_update BEFORE UPDATE ON student FOR EACH ROW
BEGIN
 IF NEW.programme_id<>OLD.programme_id AND EXISTS(SELECT 1 FROM registration WHERE student_id=OLD.student_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Programme cannot change after course registration'; END IF;
END$$
CREATE TRIGGER semester_update BEFORE UPDATE ON semester FOR EACH ROW
BEGIN
 IF (NEW.start_date<>OLD.start_date OR NEW.end_date<>OLD.end_date) AND EXISTS(SELECT 1 FROM course_offering WHERE semester_id=OLD.semester_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Semester dates cannot change after creating offerings'; END IF;
END$$
CREATE TRIGGER curriculum_insert BEFORE INSERT ON programme_course FOR EACH ROW
BEGIN
 IF NEW.recommended_term>(SELECT duration_terms FROM programme WHERE programme_id=NEW.programme_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Recommended term exceeds programme duration'; END IF;
END$$
CREATE TRIGGER curriculum_update BEFORE UPDATE ON programme_course FOR EACH ROW
BEGIN
 IF NEW.recommended_term>(SELECT duration_terms FROM programme WHERE programme_id=NEW.programme_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Recommended term exceeds programme duration'; END IF;
END$$
DELIMITER ;


-- ===== 03_views_reports.sql =====
CREATE VIEW v_fee_balance AS
SELECT b.*, COALESCE(p.paid,0) paid_amount, b.total_amount-COALESCE(p.paid,0) balance,
 CASE WHEN b.total_amount=COALESCE(p.paid,0) THEN 'PAID' WHEN b.due_date<CURRENT_DATE THEN 'OVERDUE' ELSE 'DUE' END payment_status
FROM fee_bill b LEFT JOIN (SELECT bill_id,SUM(amount) paid FROM payment GROUP BY bill_id) p ON p.bill_id=b.bill_id;

CREATE VIEW v_academic_history AS
SELECT r.registration_id,r.student_id,s.registration_no,s.full_name,s.programme_id,p.department_id,
 o.offering_id,o.faculty_id,c.course_code,c.course_title,c.credits,
 se.academic_year,se.term_name,o.section_code,r.registration_status,
 g.letter_grade,gs.grade_points,g.finalized_on
FROM registration r JOIN student s ON s.student_id=r.student_id
JOIN programme p ON p.programme_id=s.programme_id
JOIN course_offering o ON o.offering_id=r.offering_id JOIN course c ON c.course_id=o.course_id
JOIN semester se ON se.semester_id=o.semester_id
LEFT JOIN grade g ON g.registration_id=r.registration_id LEFT JOIN grade_scale gs ON gs.letter_grade=g.letter_grade;

CREATE VIEW v_attendance_summary AS
SELECT r.registration_id,r.student_id,o.offering_id,o.faculty_id,s.registration_no,s.full_name,p.department_id,c.course_code,
COUNT(cs.session_id) held_sessions,
COALESCE(SUM(a.attendance_status='PRESENT'),0) present_count,
COALESCE(SUM(a.attendance_status='ABSENT'),0) absent_count,
COUNT(cs.session_id)-COUNT(a.session_id) unmarked_count,
CASE WHEN COUNT(cs.session_id)>0 AND COUNT(cs.session_id)=COUNT(a.session_id)
THEN ROUND(100.0*SUM(a.attendance_status='PRESENT')/COUNT(cs.session_id),2) ELSE NULL END attendance_percent
FROM registration r JOIN student s ON s.student_id=r.student_id JOIN programme p ON p.programme_id=s.programme_id
JOIN course_offering o ON o.offering_id=r.offering_id JOIN course c ON c.course_id=o.course_id
LEFT JOIN class_session cs ON cs.offering_id=r.offering_id AND cs.session_date>=r.registered_on AND (r.dropped_on IS NULL OR cs.session_date<r.dropped_on)
LEFT JOIN attendance a ON a.session_id=cs.session_id AND a.registration_id=r.registration_id
GROUP BY r.registration_id,r.student_id,o.offering_id,o.faculty_id,s.registration_no,s.full_name,p.department_id,c.course_code;

CREATE VIEW v_result_analysis AS
SELECT e.exam_id,e.offering_id,o.faculty_id,c.department_id,c.course_code,e.exam_name,e.max_marks,e.weight_percent,
 COUNT(er.registration_id) entered_results,COALESCE(SUM(er.result_status='ABSENT'),0) absent_count,
 ROUND(AVG(er.marks_obtained),2) mean_marks,MAX(er.marks_obtained) highest_marks,
 (SELECT COUNT(*) FROM registration r WHERE r.offering_id=e.offering_id AND r.registration_status='ACTIVE')-COUNT(er.registration_id) pending_results
FROM examination e JOIN course_offering o ON o.offering_id=e.offering_id JOIN course c ON c.course_id=o.course_id
LEFT JOIN exam_result er ON er.exam_id=e.exam_id
GROUP BY e.exam_id,e.offering_id,o.faculty_id,c.department_id,c.course_code,e.exam_name,e.max_marks,e.weight_percent;

-- Review 2 examples. These are executable SELECT statements, not placeholders.
-- JOIN: academic history for a student (change the registration number).
SELECT * FROM v_academic_history WHERE registration_no='2026CS001';
-- Aggregate: occupied seats per section, including empty sections.
SELECT o.offering_id,c.course_code,o.section_code,o.capacity,COUNT(r.registration_id) occupied
FROM course_offering o JOIN course c ON c.course_id=o.course_id
LEFT JOIN registration r ON r.offering_id=o.offering_id AND r.registration_status='ACTIVE'
GROUP BY o.offering_id,c.course_code,o.section_code,o.capacity;
-- Nested query: students with an unpaid bill.
SELECT registration_no,full_name FROM student WHERE student_id IN
 (SELECT student_id FROM v_fee_balance WHERE balance>0);
-- View: complete attendance below a proposed 75 percent demo threshold.
SELECT * FROM v_attendance_summary WHERE attendance_percent<75;
-- Result analysis, including absent and pending counts.
SELECT * FROM v_result_analysis ORDER BY course_code,exam_name;
-- Department summary; programmes with no students remain visible.
SELECT d.department_name,COUNT(s.student_id) student_count
FROM department d LEFT JOIN programme p ON p.department_id=d.department_id
LEFT JOIN student s ON s.programme_id=p.programme_id GROUP BY d.department_id,d.department_name;


-- ===== 04_sample_data.sql =====
-- Synthetic demonstration records. All contacts use example.test.
-- Import into an EMPTY schema after 01-03. Dates reflect the setup date.
INSERT INTO department (department_code,department_name) VALUES ('CSE','Computer Science and Engineering');
INSERT INTO department (department_code,department_name) VALUES ('ECE','Electronics and Communication');
INSERT INTO programme (department_id,programme_code,programme_name,duration_terms) VALUES (1,'BTECH-CSE','BTech Computer Science',8);
INSERT INTO programme (department_id,programme_code,programme_name,duration_terms) VALUES (2,'BTECH-ECE','BTech Electronics',8);
INSERT INTO course (department_id,course_code,course_title,credits) VALUES (1,'CS301','Database Management Systems',4);
INSERT INTO course (department_id,course_code,course_title,credits) VALUES (1,'CS302','Operating Systems',4);
INSERT INTO course (department_id,course_code,course_title,credits) VALUES (1,'CS303','Data Structures',4);
INSERT INTO course (department_id,course_code,course_title,credits) VALUES (2,'EC301','Digital Electronics',3);
INSERT INTO faculty (department_id,employee_no,full_name,email,phone) VALUES (1,'FAC001','Dr Meera Rao','meera@example.test','9000000101');
INSERT INTO faculty (department_id,employee_no,full_name,email,phone) VALUES (1,'FAC002','Arjun Nair','arjun@example.test','9000000102');
INSERT INTO faculty (department_id,employee_no,full_name,email,phone) VALUES (2,'FAC003','Dr Kavya Iyer','kavya@example.test','9000000103');
INSERT INTO semester (academic_year,term_name,start_date,end_date) VALUES ('2026-27','Odd','2026-07-12','2026-12-19');
INSERT INTO student (programme_id,registration_no,full_name,date_of_birth,email,phone,admission_date,student_status) VALUES (1,'2026CS001','Aarav Sharma','2006-01-10','student1@example.test','9000010001','2025-09-15','ACTIVE');
INSERT INTO student (programme_id,registration_no,full_name,date_of_birth,email,phone,admission_date,student_status) VALUES (1,'2026CS002','Diya Patel','2006-02-10','student2@example.test','9000010002','2025-09-15','ACTIVE');
INSERT INTO student (programme_id,registration_no,full_name,date_of_birth,email,phone,admission_date,student_status) VALUES (1,'2026CS003','Ishaan Verma','2006-03-10','student3@example.test','9000010003','2025-09-15','ACTIVE');
INSERT INTO student (programme_id,registration_no,full_name,date_of_birth,email,phone,admission_date,student_status) VALUES (1,'2026CS004','Ananya Singh','2006-04-10','student4@example.test','9000010004','2025-09-15','ACTIVE');
INSERT INTO student (programme_id,registration_no,full_name,date_of_birth,email,phone,admission_date,student_status) VALUES (1,'2026CS005','Rohan Gupta','2006-05-10','student5@example.test','9000010005','2025-09-15','ACTIVE');
INSERT INTO student (programme_id,registration_no,full_name,date_of_birth,email,phone,admission_date,student_status) VALUES (1,'2026CS006','Kavya Reddy','2006-06-10','student6@example.test','9000010006','2025-09-15','ACTIVE');
INSERT INTO student (programme_id,registration_no,full_name,date_of_birth,email,phone,admission_date,student_status) VALUES (1,'2026CS007','Aditya Rao','2006-07-10','student7@example.test','9000010007','2025-09-15','ACTIVE');
INSERT INTO student (programme_id,registration_no,full_name,date_of_birth,email,phone,admission_date,student_status) VALUES (1,'2026CS008','Meera Joshi','2006-08-10','student8@example.test','9000010008','2025-09-15','ACTIVE');
INSERT INTO student (programme_id,registration_no,full_name,date_of_birth,email,phone,admission_date,student_status) VALUES (1,'2026CS009','Vihaan Shah','2006-09-10','student9@example.test','9000010009','2025-09-15','ACTIVE');
INSERT INTO student (programme_id,registration_no,full_name,date_of_birth,email,phone,admission_date,student_status) VALUES (2,'2026EC010','Sara Khan','2006-10-10','student10@example.test','9000010010','2025-09-15','ACTIVE');
INSERT INTO student (programme_id,registration_no,full_name,date_of_birth,email,phone,admission_date,student_status) VALUES (2,'2026EC011','Arjun Das','2006-11-10','student11@example.test','9000010011','2025-09-15','ACTIVE');
INSERT INTO student (programme_id,registration_no,full_name,date_of_birth,email,phone,admission_date,student_status) VALUES (2,'2026EC012','Tara Nair','2006-12-10','student12@example.test','9000010012','2025-09-15','ACTIVE');
INSERT INTO guardian (full_name,phone,email) VALUES ('Guardian 1','9000020001','guardian1@example.test');
INSERT INTO guardian (full_name,phone,email) VALUES ('Guardian 2','9000020002','guardian2@example.test');
INSERT INTO guardian (full_name,phone,email) VALUES ('Guardian 3','9000020003','guardian3@example.test');
INSERT INTO guardian (full_name,phone,email) VALUES ('Guardian 4','9000020004','guardian4@example.test');
INSERT INTO guardian (full_name,phone,email) VALUES ('Guardian 5','9000020005','guardian5@example.test');
INSERT INTO guardian (full_name,phone,email) VALUES ('Guardian 6','9000020006','guardian6@example.test');
INSERT INTO guardian (full_name,phone,email) VALUES ('Guardian 7','9000020007','guardian7@example.test');
INSERT INTO guardian (full_name,phone,email) VALUES ('Guardian 8','9000020008','guardian8@example.test');
INSERT INTO guardian (full_name,phone,email) VALUES ('Guardian 9','9000020009','guardian9@example.test');
INSERT INTO guardian (full_name,phone,email) VALUES ('Guardian 10','9000020010','guardian10@example.test');
INSERT INTO guardian (full_name,phone,email) VALUES ('Guardian 11','9000020011','guardian11@example.test');
INSERT INTO student_guardian (student_id,guardian_id,relationship_type) VALUES (1,1,'Parent');
INSERT INTO student_guardian (student_id,guardian_id,relationship_type) VALUES (2,2,'Parent');
INSERT INTO student_guardian (student_id,guardian_id,relationship_type) VALUES (3,3,'Parent');
INSERT INTO student_guardian (student_id,guardian_id,relationship_type) VALUES (4,4,'Parent');
INSERT INTO student_guardian (student_id,guardian_id,relationship_type) VALUES (5,5,'Parent');
INSERT INTO student_guardian (student_id,guardian_id,relationship_type) VALUES (6,6,'Parent');
INSERT INTO student_guardian (student_id,guardian_id,relationship_type) VALUES (7,7,'Parent');
INSERT INTO student_guardian (student_id,guardian_id,relationship_type) VALUES (8,8,'Parent');
INSERT INTO student_guardian (student_id,guardian_id,relationship_type) VALUES (9,9,'Parent');
INSERT INTO student_guardian (student_id,guardian_id,relationship_type) VALUES (10,10,'Parent');
INSERT INTO student_guardian (student_id,guardian_id,relationship_type) VALUES (11,11,'Parent');
INSERT INTO student_guardian (student_id,guardian_id,relationship_type) VALUES (12,11,'Parent');
INSERT INTO programme_course (programme_id,course_id,recommended_term,course_type) VALUES (1,1,3,'CORE');
INSERT INTO programme_course (programme_id,course_id,recommended_term,course_type) VALUES (1,2,3,'CORE');
INSERT INTO programme_course (programme_id,course_id,recommended_term,course_type) VALUES (1,3,3,'CORE');
INSERT INTO programme_course (programme_id,course_id,recommended_term,course_type) VALUES (2,4,3,'CORE');
INSERT INTO programme_course (programme_id,course_id,recommended_term,course_type) VALUES (2,1,3,'ELECTIVE');
INSERT INTO course_offering (course_id,semester_id,faculty_id,section_code,capacity) VALUES (1,1,1,'A',12);
INSERT INTO course_offering (course_id,semester_id,faculty_id,section_code,capacity) VALUES (1,1,1,'B',2);
INSERT INTO course_offering (course_id,semester_id,faculty_id,section_code,capacity) VALUES (2,1,2,'A',12);
INSERT INTO course_offering (course_id,semester_id,faculty_id,section_code,capacity) VALUES (3,1,2,'A',12);
INSERT INTO course_offering (course_id,semester_id,faculty_id,section_code,capacity) VALUES (4,1,3,'A',6);
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (1,1,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (2,1,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (3,1,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (4,1,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (5,1,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (6,1,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (7,1,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (8,1,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (9,1,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (1,3,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (2,3,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (3,3,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (4,3,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (5,3,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (6,3,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (7,3,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (8,3,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (9,3,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (10,5,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (11,5,'2026-07-12');
INSERT INTO registration (student_id,offering_id,registered_on) VALUES (12,5,'2026-07-12');
INSERT INTO class_session (offering_id,session_date,session_no,topic) VALUES (1,'2026-07-19',1,'Introduction');
INSERT INTO class_session (offering_id,session_date,session_no,topic) VALUES (1,'2026-07-26',1,'Core concepts');
INSERT INTO class_session (offering_id,session_date,session_no,topic) VALUES (1,'2026-08-02',1,'Worked examples');
INSERT INTO class_session (offering_id,session_date,session_no,topic) VALUES (1,'2026-08-09',1,'Practice session');
INSERT INTO class_session (offering_id,session_date,session_no,topic) VALUES (3,'2026-07-19',1,'Introduction');
INSERT INTO class_session (offering_id,session_date,session_no,topic) VALUES (3,'2026-07-26',1,'Core concepts');
INSERT INTO class_session (offering_id,session_date,session_no,topic) VALUES (3,'2026-08-02',1,'Worked examples');
INSERT INTO class_session (offering_id,session_date,session_no,topic) VALUES (3,'2026-08-09',1,'Practice session');
INSERT INTO class_session (offering_id,session_date,session_no,topic) VALUES (5,'2026-07-19',1,'Introduction');
INSERT INTO class_session (offering_id,session_date,session_no,topic) VALUES (5,'2026-07-26',1,'Core concepts');
INSERT INTO class_session (offering_id,session_date,session_no,topic) VALUES (5,'2026-08-02',1,'Worked examples');
INSERT INTO class_session (offering_id,session_date,session_no,topic) VALUES (5,'2026-08-09',1,'Practice session');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (1,1,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (1,2,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (1,3,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (1,4,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (2,1,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (2,2,'ABSENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (2,3,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (2,4,'ABSENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (3,1,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (3,2,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (3,3,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (3,4,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (4,1,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (4,2,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (4,3,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (4,4,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (5,1,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (5,2,'ABSENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (5,3,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (5,4,'ABSENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (6,1,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (6,2,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (6,3,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (6,4,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (7,1,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (7,2,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (7,3,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (7,4,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (8,1,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (8,2,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (8,3,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (8,4,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (9,1,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (9,2,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (9,3,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (10,5,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (10,6,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (10,7,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (10,8,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (11,5,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (11,6,'ABSENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (11,7,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (11,8,'ABSENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (12,5,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (12,6,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (12,7,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (12,8,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (13,5,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (13,6,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (13,7,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (13,8,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (14,5,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (14,6,'ABSENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (14,7,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (14,8,'ABSENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (15,5,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (15,6,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (15,7,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (15,8,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (16,5,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (16,6,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (16,7,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (16,8,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (17,5,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (17,6,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (17,7,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (17,8,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (18,5,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (18,6,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (18,7,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (18,8,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (19,9,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (19,10,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (19,11,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (19,12,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (20,9,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (20,10,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (20,11,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (20,12,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (21,9,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (21,10,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (21,11,'PRESENT');
INSERT INTO attendance (registration_id,session_id,attendance_status) VALUES (21,12,'PRESENT');
INSERT INTO examination (offering_id,exam_name,exam_date,max_marks,weight_percent) VALUES (1,'Internal','2026-08-16',50,40);
INSERT INTO examination (offering_id,exam_name,exam_date,max_marks,weight_percent) VALUES (1,'Final','2026-08-30',100,60);
INSERT INTO examination (offering_id,exam_name,exam_date,max_marks,weight_percent) VALUES (3,'Internal','2026-08-16',50,40);
INSERT INTO examination (offering_id,exam_name,exam_date,max_marks,weight_percent) VALUES (3,'Final','2026-08-30',100,60);
INSERT INTO examination (offering_id,exam_name,exam_date,max_marks,weight_percent) VALUES (5,'Internal','2026-08-16',50,40);
INSERT INTO examination (offering_id,exam_name,exam_date,max_marks,weight_percent) VALUES (5,'Final','2026-08-30',100,60);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (1,1,'SCORED',29.5e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (1,2,'SCORED',59.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (2,1,'SCORED',34.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (2,2,'SCORED',68.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (3,1,'SCORED',38.5e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (3,2,'SCORED',77.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (4,1,'SCORED',43.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (4,2,'SCORED',86.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (5,1,'SCORED',25.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (5,2,'ABSENT',NULL);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (6,1,'SCORED',29.5e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (6,2,'SCORED',59.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (7,1,'SCORED',34.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (7,2,'SCORED',68.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (8,1,'SCORED',38.5e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (8,2,'SCORED',77.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (9,1,'SCORED',43.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (10,3,'SCORED',29.5e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (10,4,'SCORED',59.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (11,3,'SCORED',34.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (11,4,'SCORED',68.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (12,3,'SCORED',38.5e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (12,4,'SCORED',77.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (13,3,'SCORED',43.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (13,4,'SCORED',86.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (14,3,'SCORED',25.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (14,4,'SCORED',50.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (15,3,'SCORED',29.5e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (15,4,'SCORED',59.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (16,3,'SCORED',34.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (16,4,'SCORED',68.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (17,3,'SCORED',38.5e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (17,4,'SCORED',77.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (18,3,'SCORED',43.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (18,4,'SCORED',86.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (19,5,'SCORED',25.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (19,6,'SCORED',50.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (20,5,'SCORED',29.5e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (20,6,'SCORED',59.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (21,5,'SCORED',34.0e0);
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained) VALUES (21,6,'SCORED',68.0e0);
INSERT INTO grade_scale (letter_grade,minimum_score,grade_points) VALUES ('O',90,10);
INSERT INTO grade_scale (letter_grade,minimum_score,grade_points) VALUES ('A+',80,9);
INSERT INTO grade_scale (letter_grade,minimum_score,grade_points) VALUES ('A',70,8);
INSERT INTO grade_scale (letter_grade,minimum_score,grade_points) VALUES ('B+',60,7);
INSERT INTO grade_scale (letter_grade,minimum_score,grade_points) VALUES ('B',50,6);
INSERT INTO grade_scale (letter_grade,minimum_score,grade_points) VALUES ('C',40,5);
INSERT INTO grade_scale (letter_grade,minimum_score,grade_points) VALUES ('F',0,0);
INSERT INTO fee_bill (student_id,semester_id,bill_no,description,issued_on,due_date,total_amount) VALUES (1,1,'BILL-001','Semester tuition','2026-07-12','2026-08-26',20000);
INSERT INTO fee_bill (student_id,semester_id,bill_no,description,issued_on,due_date,total_amount) VALUES (2,1,'BILL-002','Semester tuition','2026-07-12','2026-08-26',20000);
INSERT INTO fee_bill (student_id,semester_id,bill_no,description,issued_on,due_date,total_amount) VALUES (3,1,'BILL-003','Semester tuition','2026-07-12','2026-08-26',20000);
INSERT INTO fee_bill (student_id,semester_id,bill_no,description,issued_on,due_date,total_amount) VALUES (4,1,'BILL-004','Semester tuition','2026-07-12','2026-08-26',20000);
INSERT INTO fee_bill (student_id,semester_id,bill_no,description,issued_on,due_date,total_amount) VALUES (5,1,'BILL-005','Semester tuition','2026-07-12','2026-08-26',20000);
INSERT INTO fee_bill (student_id,semester_id,bill_no,description,issued_on,due_date,total_amount) VALUES (6,1,'BILL-006','Semester tuition','2026-07-12','2026-08-26',20000);
INSERT INTO fee_bill (student_id,semester_id,bill_no,description,issued_on,due_date,total_amount) VALUES (7,1,'BILL-007','Semester tuition','2026-07-12','2026-08-26',20000);
INSERT INTO fee_bill (student_id,semester_id,bill_no,description,issued_on,due_date,total_amount) VALUES (8,1,'BILL-008','Semester tuition','2026-07-12','2026-08-26',20000);
INSERT INTO fee_bill (student_id,semester_id,bill_no,description,issued_on,due_date,total_amount) VALUES (9,1,'BILL-009','Semester tuition','2026-07-12','2026-08-26',20000);
INSERT INTO fee_bill (student_id,semester_id,bill_no,description,issued_on,due_date,total_amount) VALUES (10,1,'BILL-010','Semester tuition','2026-07-12','2026-08-26',18000);
INSERT INTO fee_bill (student_id,semester_id,bill_no,description,issued_on,due_date,total_amount) VALUES (11,1,'BILL-011','Semester tuition','2026-07-12','2026-08-26',18000);
INSERT INTO fee_bill (student_id,semester_id,bill_no,description,issued_on,due_date,total_amount) VALUES (12,1,'BILL-012','Semester tuition','2026-07-12','2026-08-26',18000);
INSERT INTO payment (bill_id,receipt_no,paid_on,amount,payment_mode,transaction_reference) VALUES (1,'RCPT-001','2026-07-22',20000,'BANK_TRANSFER','DEMO-TXN-001');
INSERT INTO payment (bill_id,receipt_no,paid_on,amount,payment_mode,transaction_reference) VALUES (2,'RCPT-002','2026-07-22',8000,'BANK_TRANSFER','DEMO-TXN-002');
INSERT INTO payment (bill_id,receipt_no,paid_on,amount,payment_mode,transaction_reference) VALUES (3,'RCPT-003','2026-07-22',20000,'BANK_TRANSFER','DEMO-TXN-003');
INSERT INTO payment (bill_id,receipt_no,paid_on,amount,payment_mode,transaction_reference) VALUES (4,'RCPT-004','2026-07-22',8000,'BANK_TRANSFER','DEMO-TXN-004');
INSERT INTO payment (bill_id,receipt_no,paid_on,amount,payment_mode,transaction_reference) VALUES (5,'RCPT-005','2026-07-22',8000,'BANK_TRANSFER','DEMO-TXN-005');
INSERT INTO payment (bill_id,receipt_no,paid_on,amount,payment_mode,transaction_reference) VALUES (6,'RCPT-006','2026-07-22',8000,'BANK_TRANSFER','DEMO-TXN-006');
INSERT INTO payment (bill_id,receipt_no,paid_on,amount,payment_mode,transaction_reference) VALUES (7,'RCPT-007','2026-07-22',20000,'BANK_TRANSFER','DEMO-TXN-007');
INSERT INTO payment (bill_id,receipt_no,paid_on,amount,payment_mode,transaction_reference) VALUES (8,'RCPT-008','2026-07-22',8000,'BANK_TRANSFER','DEMO-TXN-008');
INSERT INTO payment (bill_id,receipt_no,paid_on,amount,payment_mode,transaction_reference) VALUES (9,'RCPT-009','2026-07-22',8000,'BANK_TRANSFER','DEMO-TXN-009');
INSERT INTO app_user (username,password_hash,role,student_id,faculty_id,department_id) VALUES ('admin','scrypt:32768:8:1$N3QkVmuhM8dRGCL3$b17a3b269e35384da4e7cced2822bf6ab95da62c44b4d653169f75da9f12b071f1769ae681aa92c2bc02882b987ddeb0a6a12660dda8d1119b44a4df0b8ea019','ADMIN',NULL,NULL,NULL);
INSERT INTO app_user (username,password_hash,role,student_id,faculty_id,department_id) VALUES ('faculty','scrypt:32768:8:1$I4zcJKqHAgB41tyo$0935465f0e288bc39b1d9acc95d8362164d3f11a551d5debcf078a85b38c358de1559d4970866271572fc9b388170912c464b5e45c15e9d4d6c9f8bc6176a21e','FACULTY',NULL,1,NULL);
INSERT INTO app_user (username,password_hash,role,student_id,faculty_id,department_id) VALUES ('exams','scrypt:32768:8:1$ljaHU08OvD76HE88$f4d49ea7ee530309b36c9bdc78ef421f818201c7a1b04099e04f84724a234d47b8068fe0c7d4f91c04a3d713387d573c9d8c3453c242e3d67601d72ecfdac9e0','EXAMS',NULL,NULL,NULL);
INSERT INTO app_user (username,password_hash,role,student_id,faculty_id,department_id) VALUES ('accounts','scrypt:32768:8:1$KquyCTLxxGiuXcSt$bf5e03b1fe4bf868ae3bf32fc35c1af1a7b041ea26a276bf18ef8f7d17e5187628066fff4781458257c84d86464dc4c18650f1de62cb13124d711c53b6f39487','ACCOUNTS',NULL,NULL,NULL);
INSERT INTO app_user (username,password_hash,role,student_id,faculty_id,department_id) VALUES ('student','scrypt:32768:8:1$JMsBvBOkWdIMgEEe$4755ad3bf2bf1b972f61aa24633ee5d10c914e903b9180aff2a050ad4fe666b27be6fc7d64038b8cee75f566693da0dcd78aa478df662c3da2665b71d55ae1da','STUDENT',1,NULL,NULL);
INSERT INTO app_user (username,password_hash,role,student_id,faculty_id,department_id) VALUES ('student2','scrypt:32768:8:1$DXauOBnrOgt7q59D$6e9900ef06ba25bf2ca8c7de780462194757e8b2ad60d70ffae1dd4caa897fcf9ccba8441f59cb98339a85accdfb7e4901bf974be831654b13ce64820ca43b63','STUDENT',2,NULL,NULL);
INSERT INTO app_user (username,password_hash,role,student_id,faculty_id,department_id) VALUES ('hod','scrypt:32768:8:1$5PSrh214TRXJMF3B$df0a6d9e39982a16b8b142388a14258a48f7c4c8fdd85ac79edc3258cf234c6787632c51714011166adfc506683fa8d207e510587884ebf9b73bf8b8bd16793f','HOD',NULL,NULL,1);


-- ===== 05_minimum_five_per_table.sql =====
-- Additional synthetic records for the final-presentation requirement.
-- Run only after 04_sample_data.sql in a NEW database.
-- No real student or faculty details are used.

INSERT INTO department (department_code,department_name) VALUES
 ('ME','Mechanical Engineering'),
 ('CIV','Civil Engineering'),
 ('BIO','Biological Sciences');

INSERT INTO programme (department_id,programme_code,programme_name,duration_terms) VALUES
 (3,'BTECH-ME','BTech Mechanical Engineering',8),
 (4,'BTECH-CIV','BTech Civil Engineering',8),
 (5,'BSC-BIO','BSc Biological Sciences',6);

INSERT INTO course (department_id,course_code,course_title,credits) VALUES
 (3,'ME301','Engineering Mechanics',4);

INSERT INTO faculty (department_id,employee_no,full_name,email,phone) VALUES
 (3,'FAC004','Dr Nisha Sen','nisha@example.test','9000000104'),
 (4,'FAC005','Dr Vivek Rao','vivek@example.test','9000000105');

INSERT INTO semester (academic_year,term_name,start_date,end_date) VALUES
 ('2025-26','Odd','2025-07-01','2025-12-20'),
 ('2025-26','Even','2026-01-05','2026-05-25'),
 ('2026-27','Even','2027-01-05','2027-05-25'),
 ('2027-28','Odd','2027-07-01','2027-12-20');

-- All nine registrations in offering 3 have both examination outcomes.
-- Derive grades from their weighted marks and the stored grade scale.
INSERT INTO grade (registration_id,letter_grade,finalized_on)
SELECT score.registration_id,
       (SELECT gs.letter_grade FROM grade_scale AS gs
        WHERE gs.minimum_score <= score.weighted_score
        ORDER BY gs.minimum_score DESC LIMIT 1),
       '2026-10-06'
FROM (
 SELECT r.registration_id,
        SUM(CASE WHEN er.result_status='ABSENT' THEN 0
                 ELSE er.marks_obtained/e.max_marks*e.weight_percent END) AS weighted_score
 FROM registration AS r
 JOIN examination AS e ON e.offering_id=r.offering_id
 JOIN exam_result AS er ON er.registration_id=r.registration_id AND er.exam_id=e.exam_id
 WHERE r.offering_id=3 AND r.registration_status='ACTIVE'
 GROUP BY r.registration_id
 HAVING COUNT(*)=(SELECT COUNT(*) FROM examination WHERE offering_id=3)
) AS score;

INSERT INTO audit_event (user_id,action,detail,created_at) VALUES
 (1,'DEMO_SEED','Synthetic setup record 1','2026-10-06 08:00:01'),
 (2,'DEMO_SEED','Synthetic setup record 2','2026-10-06 08:00:02'),
 (3,'DEMO_SEED','Synthetic setup record 3','2026-10-06 08:00:03'),
 (4,'DEMO_SEED','Synthetic setup record 4','2026-10-06 08:00:04'),
 (5,'DEMO_SEED','Synthetic setup record 5','2026-10-06 08:00:05');


-- ===== Live SELECT queries and count verification =====
-- Run with: mysql -h 127.0.0.1 -P 3308 -u root -p college_pbl_presentation
-- These queries do not change data. The UI demonstration performs INSERT/DELETE.

SHOW TABLES;
SHOW CREATE TABLE student;
SHOW CREATE TABLE registration;

-- Primary key, foreign key, joins: students enrolled in course sections.
SELECT s.registration_no, s.full_name, c.course_code, o.section_code,
       sem.academic_year, sem.term_name
FROM student AS s
JOIN registration AS r ON r.student_id=s.student_id
JOIN course_offering AS o ON o.offering_id=r.offering_id
JOIN course AS c ON c.course_id=o.course_id
JOIN semester AS sem ON sem.semester_id=o.semester_id
WHERE r.registration_status='ACTIVE'
ORDER BY s.registration_no, c.course_code
LIMIT 15;

-- Aggregate function: active enrolment by section.
SELECT c.course_code, o.section_code, COUNT(r.registration_id) AS active_students
FROM course_offering AS o
JOIN course AS c ON c.course_id=o.course_id
LEFT JOIN registration AS r ON r.offering_id=o.offering_id
 AND r.registration_status='ACTIVE'
GROUP BY o.offering_id, c.course_code, o.section_code
ORDER BY c.course_code, o.section_code;

-- A derived balance: bill total less confirmed payments.
SELECT b.bill_no, s.full_name, b.total_amount, b.paid_amount, b.balance
FROM v_fee_balance AS b
JOIN student AS s ON s.student_id=b.student_id
ORDER BY b.bill_no
LIMIT 10;

-- Proof of at least five records in every base table after running 05.
SELECT 'department' AS table_name,COUNT(*) AS records FROM department
UNION ALL SELECT 'programme',COUNT(*) FROM programme
UNION ALL SELECT 'course',COUNT(*) FROM course
UNION ALL SELECT 'faculty',COUNT(*) FROM faculty
UNION ALL SELECT 'semester',COUNT(*) FROM semester
UNION ALL SELECT 'student',COUNT(*) FROM student
UNION ALL SELECT 'guardian',COUNT(*) FROM guardian
UNION ALL SELECT 'student_guardian',COUNT(*) FROM student_guardian
UNION ALL SELECT 'programme_course',COUNT(*) FROM programme_course
UNION ALL SELECT 'course_offering',COUNT(*) FROM course_offering
UNION ALL SELECT 'registration',COUNT(*) FROM registration
UNION ALL SELECT 'class_session',COUNT(*) FROM class_session
UNION ALL SELECT 'attendance',COUNT(*) FROM attendance
UNION ALL SELECT 'examination',COUNT(*) FROM examination
UNION ALL SELECT 'exam_result',COUNT(*) FROM exam_result
UNION ALL SELECT 'grade_scale',COUNT(*) FROM grade_scale
UNION ALL SELECT 'grade',COUNT(*) FROM grade
UNION ALL SELECT 'fee_bill',COUNT(*) FROM fee_bill
UNION ALL SELECT 'payment',COUNT(*) FROM payment
UNION ALL SELECT 'app_user',COUNT(*) FROM app_user
UNION ALL SELECT 'audit_event',COUNT(*) FROM audit_event;
