-- Additional synthetic records requested for the presentation.
-- Run after 05_minimum_five_per_table.sql.
-- Stable codes and receipt numbers make these statements safe to rerun.

INSERT IGNORE INTO department (department_code,department_name) VALUES
 ('EEE','Electrical and Electronics Engineering'),
 ('CHEM','Chemistry'),
 ('MATH','Mathematics'),
 ('PHY','Physics'),
 ('ENG','English and Communication'),
 ('BBA','Business Administration');

INSERT IGNORE INTO programme (department_id,programme_code,programme_name,duration_terms)
 SELECT department_id,'BTECH-EEE','BTech Electrical Engineering',8 FROM department WHERE department_code='EEE';
INSERT IGNORE INTO programme (department_id,programme_code,programme_name,duration_terms)
 SELECT department_id,'BSC-CHEM','BSc Chemistry',6 FROM department WHERE department_code='CHEM';
INSERT IGNORE INTO programme (department_id,programme_code,programme_name,duration_terms)
 SELECT department_id,'BSC-MATH','BSc Mathematics',6 FROM department WHERE department_code='MATH';
INSERT IGNORE INTO programme (department_id,programme_code,programme_name,duration_terms)
 SELECT department_id,'BSC-PHY','BSc Physics',6 FROM department WHERE department_code='PHY';
INSERT IGNORE INTO programme (department_id,programme_code,programme_name,duration_terms)
 SELECT department_id,'BA-ENG','BA English',6 FROM department WHERE department_code='ENG';
INSERT IGNORE INTO programme (department_id,programme_code,programme_name,duration_terms)
 SELECT department_id,'BBA','Bachelor of Business Administration',6 FROM department WHERE department_code='BBA';

INSERT IGNORE INTO course (department_id,course_code,course_title,credits)
 SELECT department_id,'EE301','Power Systems',4 FROM department WHERE department_code='EEE';
INSERT IGNORE INTO course (department_id,course_code,course_title,credits)
 SELECT department_id,'CH301','Industrial Chemistry',4 FROM department WHERE department_code='CHEM';
INSERT IGNORE INTO course (department_id,course_code,course_title,credits)
 SELECT department_id,'MA301','Discrete Mathematics',4 FROM department WHERE department_code='MATH';
INSERT IGNORE INTO course (department_id,course_code,course_title,credits)
 SELECT department_id,'PH301','Applied Physics',4 FROM department WHERE department_code='PHY';
INSERT IGNORE INTO course (department_id,course_code,course_title,credits)
 SELECT department_id,'EN301','Technical Communication',3 FROM department WHERE department_code='ENG';
INSERT IGNORE INTO course (department_id,course_code,course_title,credits)
 SELECT department_id,'MG301','Principles of Management',3 FROM department WHERE department_code='BBA';

INSERT IGNORE INTO faculty (department_id,employee_no,full_name,email,phone)
 SELECT department_id,'FAC006','Dr Priya Menon','priya@example.test','9000000106' FROM department WHERE department_code='EEE';
INSERT IGNORE INTO faculty (department_id,employee_no,full_name,email,phone)
 SELECT department_id,'FAC007','Dr Rahul Bose','rahul@example.test','9000000107' FROM department WHERE department_code='CHEM';
INSERT IGNORE INTO faculty (department_id,employee_no,full_name,email,phone)
 SELECT department_id,'FAC008','Dr Sneha Kulkarni','sneha@example.test','9000000108' FROM department WHERE department_code='MATH';
INSERT IGNORE INTO faculty (department_id,employee_no,full_name,email,phone)
 SELECT department_id,'FAC009','Dr Kiran Shah','kiran@example.test','9000000109' FROM department WHERE department_code='PHY';
INSERT IGNORE INTO faculty (department_id,employee_no,full_name,email,phone)
 SELECT department_id,'FAC010','Dr Anita Das','anita@example.test','9000000110' FROM department WHERE department_code='ENG';
INSERT IGNORE INTO faculty (department_id,employee_no,full_name,email,phone)
 SELECT department_id,'FAC011','Dr Mohan Roy','mohan@example.test','9000000111' FROM department WHERE department_code='BBA';

INSERT IGNORE INTO semester (academic_year,term_name,start_date,end_date) VALUES
 ('2027-28','Even','2028-01-05','2028-05-25'),
 ('2028-29','Odd','2028-07-01','2028-12-20'),
 ('2028-29','Even','2029-01-05','2029-05-25'),
 ('2029-30','Odd','2029-07-01','2029-12-20'),
 ('2029-30','Even','2030-01-05','2030-05-25'),
 ('2030-31','Odd','2030-07-01','2030-12-20');

INSERT IGNORE INTO programme_course (programme_id,course_id,recommended_term,course_type)
 SELECT p.programme_id,c.course_id,3,'CORE' FROM programme p JOIN course c ON c.course_code='EE301' WHERE p.programme_code='BTECH-EEE';
INSERT IGNORE INTO programme_course (programme_id,course_id,recommended_term,course_type)
 SELECT p.programme_id,c.course_id,3,'CORE' FROM programme p JOIN course c ON c.course_code='CH301' WHERE p.programme_code='BSC-CHEM';
INSERT IGNORE INTO programme_course (programme_id,course_id,recommended_term,course_type)
 SELECT p.programme_id,c.course_id,3,'CORE' FROM programme p JOIN course c ON c.course_code='MA301' WHERE p.programme_code='BSC-MATH';
INSERT IGNORE INTO programme_course (programme_id,course_id,recommended_term,course_type)
 SELECT p.programme_id,c.course_id,3,'CORE' FROM programme p JOIN course c ON c.course_code='PH301' WHERE p.programme_code='BSC-PHY';
INSERT IGNORE INTO programme_course (programme_id,course_id,recommended_term,course_type)
 SELECT p.programme_id,c.course_id,3,'CORE' FROM programme p JOIN course c ON c.course_code='EN301' WHERE p.programme_code='BA-ENG';
INSERT IGNORE INTO programme_course (programme_id,course_id,recommended_term,course_type)
 SELECT p.programme_id,c.course_id,3,'CORE' FROM programme p JOIN course c ON c.course_code='MG301' WHERE p.programme_code='BBA';

INSERT IGNORE INTO course_offering (course_id,semester_id,faculty_id,section_code,capacity)
 SELECT c.course_id,s.semester_id,f.faculty_id,'A',30 FROM course c JOIN semester s ON s.academic_year='2026-27' AND s.term_name='Odd' JOIN faculty f ON f.employee_no='FAC006' WHERE c.course_code='EE301';
INSERT IGNORE INTO course_offering (course_id,semester_id,faculty_id,section_code,capacity)
 SELECT c.course_id,s.semester_id,f.faculty_id,'A',30 FROM course c JOIN semester s ON s.academic_year='2026-27' AND s.term_name='Odd' JOIN faculty f ON f.employee_no='FAC007' WHERE c.course_code='CH301';
INSERT IGNORE INTO course_offering (course_id,semester_id,faculty_id,section_code,capacity)
 SELECT c.course_id,s.semester_id,f.faculty_id,'A',30 FROM course c JOIN semester s ON s.academic_year='2026-27' AND s.term_name='Odd' JOIN faculty f ON f.employee_no='FAC008' WHERE c.course_code='MA301';
INSERT IGNORE INTO course_offering (course_id,semester_id,faculty_id,section_code,capacity)
 SELECT c.course_id,s.semester_id,f.faculty_id,'A',30 FROM course c JOIN semester s ON s.academic_year='2026-27' AND s.term_name='Odd' JOIN faculty f ON f.employee_no='FAC009' WHERE c.course_code='PH301';
INSERT IGNORE INTO course_offering (course_id,semester_id,faculty_id,section_code,capacity)
 SELECT c.course_id,s.semester_id,f.faculty_id,'A',30 FROM course c JOIN semester s ON s.academic_year='2026-27' AND s.term_name='Odd' JOIN faculty f ON f.employee_no='FAC010' WHERE c.course_code='EN301';
INSERT IGNORE INTO course_offering (course_id,semester_id,faculty_id,section_code,capacity)
 SELECT c.course_id,s.semester_id,f.faculty_id,'A',30 FROM course c JOIN semester s ON s.academic_year='2026-27' AND s.term_name='Odd' JOIN faculty f ON f.employee_no='FAC011' WHERE c.course_code='MG301';

INSERT IGNORE INTO examination (offering_id,exam_name,exam_date,max_marks,weight_percent)
 SELECT o.offering_id,'Final','2026-09-15',100,100 FROM course_offering o JOIN course c ON c.course_id=o.course_id WHERE c.course_code='EE301' AND o.section_code='A';
INSERT IGNORE INTO examination (offering_id,exam_name,exam_date,max_marks,weight_percent)
 SELECT o.offering_id,'Final','2026-09-15',100,100 FROM course_offering o JOIN course c ON c.course_id=o.course_id WHERE c.course_code='CH301' AND o.section_code='A';
INSERT IGNORE INTO examination (offering_id,exam_name,exam_date,max_marks,weight_percent)
 SELECT o.offering_id,'Final','2026-09-15',100,100 FROM course_offering o JOIN course c ON c.course_id=o.course_id WHERE c.course_code='MA301' AND o.section_code='A';
INSERT IGNORE INTO examination (offering_id,exam_name,exam_date,max_marks,weight_percent)
 SELECT o.offering_id,'Final','2026-09-15',100,100 FROM course_offering o JOIN course c ON c.course_id=o.course_id WHERE c.course_code='PH301' AND o.section_code='A';
INSERT IGNORE INTO examination (offering_id,exam_name,exam_date,max_marks,weight_percent)
 SELECT o.offering_id,'Final','2026-09-15',100,100 FROM course_offering o JOIN course c ON c.course_id=o.course_id WHERE c.course_code='EN301' AND o.section_code='A';
INSERT IGNORE INTO examination (offering_id,exam_name,exam_date,max_marks,weight_percent)
 SELECT o.offering_id,'Final','2026-09-15',100,100 FROM course_offering o JOIN course c ON c.course_id=o.course_id WHERE c.course_code='MG301' AND o.section_code='A';

INSERT IGNORE INTO grade_scale (letter_grade,minimum_score,grade_points) VALUES
 ('C+',45,5.5),('D+',35,4.5),('D',30,4),('E',20,2);

-- Complete one intentionally partial result, then finalize two additional grades.
INSERT INTO exam_result (registration_id,exam_id,result_status,marks_obtained)
SELECT 9,2,'SCORED',86
WHERE NOT EXISTS (
 SELECT 1 FROM exam_result WHERE registration_id=9 AND exam_id=2
);
INSERT IGNORE INTO grade (registration_id,letter_grade,finalized_on)
SELECT score.registration_id,
       (SELECT gs.letter_grade FROM grade_scale gs
        WHERE gs.minimum_score<=score.weighted_score
        ORDER BY gs.minimum_score DESC LIMIT 1),
       '2026-10-07'
FROM (
 SELECT r.registration_id,
        SUM(CASE WHEN er.result_status='ABSENT' THEN 0
                 ELSE er.marks_obtained/e.max_marks*e.weight_percent END) weighted_score
 FROM registration r
 JOIN examination e ON e.offering_id=r.offering_id
 JOIN exam_result er ON er.registration_id=r.registration_id AND er.exam_id=e.exam_id
 WHERE r.registration_id IN (9,19) AND r.registration_status='ACTIVE'
 GROUP BY r.registration_id
 HAVING COUNT(*)=2
) score;

INSERT IGNORE INTO payment (bill_id,receipt_no,paid_on,amount,payment_mode,transaction_reference) VALUES
 (10,'RCPT-010','2026-07-22',8000,'BANK_TRANSFER','DEMO-TXN-010'),
 (11,'RCPT-011','2026-07-22',8000,'BANK_TRANSFER','DEMO-TXN-011');

-- New sign-ins reuse the local demonstration password hash from admin.
INSERT IGNORE INTO app_user (username,password_hash,role,student_id,faculty_id,department_id)
 SELECT 'faculty2',password_hash,'FACULTY',NULL,2,NULL FROM app_user WHERE username='admin';
INSERT IGNORE INTO app_user (username,password_hash,role,student_id,faculty_id,department_id)
 SELECT 'student3',password_hash,'STUDENT',3,NULL,NULL FROM app_user WHERE username='admin';
INSERT IGNORE INTO app_user (username,password_hash,role,student_id,faculty_id,department_id)
 SELECT 'hod_ece',password_hash,'HOD',NULL,NULL,2 FROM app_user WHERE username='admin';
INSERT IGNORE INTO app_user (username,password_hash,role,student_id,faculty_id,department_id)
 SELECT 'student4',password_hash,'STUDENT',4,NULL,NULL FROM app_user WHERE username='admin';

INSERT INTO audit_event (user_id,action,detail,created_at)
SELECT (SELECT user_id FROM app_user WHERE username='admin'),'DEMO_SEED','Synthetic setup record 6','2026-10-07 08:00:06'
WHERE NOT EXISTS (SELECT 1 FROM audit_event WHERE action='DEMO_SEED' AND detail='Synthetic setup record 6');
INSERT INTO audit_event (user_id,action,detail,created_at)
SELECT (SELECT user_id FROM app_user WHERE username='faculty'),'DEMO_SEED','Synthetic setup record 7','2026-10-07 08:00:07'
WHERE NOT EXISTS (SELECT 1 FROM audit_event WHERE action='DEMO_SEED' AND detail='Synthetic setup record 7');
INSERT INTO audit_event (user_id,action,detail,created_at)
SELECT (SELECT user_id FROM app_user WHERE username='exams'),'DEMO_SEED','Synthetic setup record 8','2026-10-07 08:00:08'
WHERE NOT EXISTS (SELECT 1 FROM audit_event WHERE action='DEMO_SEED' AND detail='Synthetic setup record 8');
INSERT INTO audit_event (user_id,action,detail,created_at)
SELECT (SELECT user_id FROM app_user WHERE username='accounts'),'DEMO_SEED','Synthetic setup record 9','2026-10-07 08:00:09'
WHERE NOT EXISTS (SELECT 1 FROM audit_event WHERE action='DEMO_SEED' AND detail='Synthetic setup record 9');
INSERT INTO audit_event (user_id,action,detail,created_at)
SELECT (SELECT user_id FROM app_user WHERE username='student'),'DEMO_SEED','Synthetic setup record 10','2026-10-07 08:00:10'
WHERE NOT EXISTS (SELECT 1 FROM audit_event WHERE action='DEMO_SEED' AND detail='Synthetic setup record 10');
INSERT INTO audit_event (user_id,action,detail,created_at)
SELECT (SELECT user_id FROM app_user WHERE username='hod'),'DEMO_SEED','Synthetic setup record 11','2026-10-07 08:00:11'
WHERE NOT EXISTS (SELECT 1 FROM audit_event WHERE action='DEMO_SEED' AND detail='Synthetic setup record 11');
