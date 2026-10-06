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
