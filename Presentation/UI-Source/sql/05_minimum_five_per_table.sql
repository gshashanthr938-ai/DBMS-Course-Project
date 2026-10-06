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
