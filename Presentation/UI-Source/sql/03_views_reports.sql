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
