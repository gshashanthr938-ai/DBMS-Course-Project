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
