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
