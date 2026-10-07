# Professor live-input demonstration

## Prepare before presenting

The quickest option is to run this once from the `Presentation` folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\START_PRESENTATION.ps1
```

It starts the application, opens the website and opens the MySQL console. The
manual steps below perform the same setup.

1. Open PowerShell in `Presentation/UI-Source`.
2. Run `powershell -ExecutionPolicy Bypass -File .\start.ps1`.
3. Open `http://127.0.0.1:5080` and sign in as `admin`.
4. Open a second PowerShell window in `Presentation`.
5. Run `powershell -ExecutionPolicy Bypass -File .\Open_Database_Console.ps1`.
6. Keep the browser on one side and the database console on the other side.

## Demonstration 1: simple insert and delete

Ask the professor for a department code and department name.

1. In the website, open **Departments** and add that record.
2. In the database console, run:

```sql
SELECT department_id, department_code, department_name
FROM department
ORDER BY department_id DESC
LIMIT 5;
```

The new website input appears as a real row in MySQL. Delete the demonstration
department through the website only if no programme, course or faculty record
uses it. Run the same query again to show that the row is gone.

## Demonstration 2: show a foreign-key relationship

Ask the professor for a faculty name and choose an existing department in the
website. After saving, run:

```sql
SELECT f.faculty_id, f.employee_no, f.full_name,
       d.department_code, d.department_name
FROM faculty AS f
JOIN department AS d ON d.department_id = f.department_id
ORDER BY f.faculty_id DESC
LIMIT 5;
```

Explain that the faculty table stores `department_id`, while the JOIN retrieves
the department name. This demonstrates a one-to-many relationship.

## Demonstration 3: show the student relationship chain

After adding a student under an existing programme, run:

```sql
SELECT s.student_id, s.registration_no, s.full_name,
       p.programme_code, d.department_code
FROM student AS s
JOIN programme AS p ON p.programme_id = s.programme_id
JOIN department AS d ON d.department_id = p.department_id
ORDER BY s.student_id DESC
LIMIT 5;
```

Explain the chain: Student belongs to Programme, and Programme belongs to
Department. The database stores IDs as foreign keys and the JOIN shows the
human-readable names.

## Demonstration 4: many-to-many registration

After registering a student in a course offering, run:

```sql
SELECT r.registration_id, s.registration_no, s.full_name,
       c.course_code, se.academic_year, se.term_name, o.section_code
FROM registration AS r
JOIN student AS s ON s.student_id = r.student_id
JOIN course_offering AS o ON o.offering_id = r.offering_id
JOIN course AS c ON c.course_id = o.course_id
JOIN semester AS se ON se.semester_id = o.semester_id
ORDER BY r.registration_id DESC
LIMIT 10;
```

Explain that Registration is the bridge between Student and Course Offering.
It converts their many-to-many relationship into two one-to-many relationships.

## Useful proof commands

```sql
SHOW TABLES;
SELECT COUNT(*) AS total_students FROM student;
SELECT COUNT(*) AS total_registrations FROM registration;
SELECT * FROM v_academic_history ORDER BY registration_id DESC LIMIT 10;
SELECT * FROM v_attendance_summary ORDER BY registration_id DESC LIMIT 10;
SELECT * FROM v_fee_balance ORDER BY bill_id DESC LIMIT 10;
```

## If the browser says connection refused

The website or MySQL server is stopped. Run `UI-Source/start.ps1` again and
wait until it prints `Campus Ledger is available at http://127.0.0.1:5080`.
Do this before the presentation and avoid closing the server processes.
