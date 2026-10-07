# Campus Ledger viva guide based on the shared audio

## What the audio says the professor may check

1. Each member's real contribution to the prototype.
2. The public GitHub repository and its folders.
3. Frontend, backend and database source files.
4. Presentation and report files required by the official brief.
5. Enough sample records to demonstrate tables and queries.
6. The technology stack and the database connector.
7. A live insert and delete through the prototype.
8. Normalization questions.
9. The final project report.

The audio describes another team's React, Java and JDBC stack. Campus Ledger
uses a different stack: HTML/CSS/JavaScript with Jinja templates, Python Flask,
PyMySQL and MySQL 8. Do not answer React, Java or JDBC for this project.

## Thirty-second project introduction

Campus Ledger is a Student and College Management System. It replaces separate
student, academic, examination and accounts files with one relational MySQL
database. A Flask web application lets authorized users manage admissions,
guardians, courses, registrations, attendance, examinations, grades, fee bills,
payments and reports. The schema has 21 base tables, four views and six roles.

## GitHub folder explanation

Public repository:
https://github.com/gshashanthr938-ai/DBMS-Course-Project

- `Presentation/UI-Source/app.py`, `db.py` and `catalog.py`: backend.
- `Presentation/UI-Source/templates`: HTML/Jinja frontend pages.
- `Presentation/UI-Source/static`: CSS and JavaScript frontend assets.
- `Presentation/UI-Source/sql`: schema, procedures, triggers, views and data.
- `Presentation/UI-Source/tests`: automated tests.
- `Presentation/screenshots`: screenshots of the working screens.
- `Presentation`: final PPT/PDF, ER diagrams, SQL and demo evidence.
- `Project-Report`: final report PDF and editable metadata/builder files.

The supplied official brief asks for the final PPT/PDF, ER image, SQL file, UI
source and screenshots. The audio mentions PPT-1, PPT-2 and PPT-3 for another
class. Follow the exact instructions given to this section rather than inventing
three presentations.

## Technology stack

| Layer | Technology | Purpose |
|---|---|---|
| Frontend | HTML5, CSS3, Jinja2 templates, vanilla JavaScript | Forms, tables, navigation and responsive pages |
| Backend | Python 3.12 and Flask 3.1.3 | Routes, validation, roles and workflows |
| Application server | Waitress 3.0.2 | Serves the Flask app locally |
| Connector | PyMySQL 1.2.3 | Sends parameterized SQL from Python to MySQL |
| Database | MySQL 8.0.46 with InnoDB | Tables, relationships, constraints and transactions |
| Testing | pytest 9.1.1 and Flask test client | Automated application/database tests |

Exact answer: "The frontend uses HTML, CSS, Jinja templates and vanilla
JavaScript. The backend uses Python Flask. PyMySQL connects Flask to MySQL 8.
Waitress runs the local web server, and pytest runs the automated tests."

If the professor wants only two short lines, say:

- Frontend: HTML, CSS, JavaScript and Jinja.
- Backend: Python Flask with MySQL through PyMySQL.

## Website flow

1. The browser requests a page from Flask.
2. Flask checks the logged-in user and role.
3. Flask validates form input and its CSRF token.
4. `db.py` uses PyMySQL to run a parameterized SQL statement.
5. MySQL checks keys, constraints, procedures or triggers.
6. Flask reads the result and renders an HTML/Jinja template.
7. The browser shows the updated page.

The browser does not store the college data. MySQL stores it in
`college_pbl_presentation` on local port 3308. The website runs on port 5080.

## Frontend questions

**What is the frontend?**

The visible browser interface. It uses HTML templates, CSS and a small amount
of JavaScript.

**Is the frontend React?**

No. Campus Ledger uses server-rendered Jinja2 templates and vanilla JavaScript.

**What does JavaScript do?**

It automatically submits selected filters, asks for confirmation before a
delete, supports print buttons, returns to the previous page and highlights the
active navigation link.

**Is the interface responsive?**

Yes. The CSS has layouts for wide screens, screens below 1000 pixels, mobile
screens below 650 pixels and printing.

**What is CRUD?**

Create adds data, Read displays data, Update changes data and Delete removes
data when relationships allow it.

## Backend questions

**What does Flask do?**

Flask receives browser requests, checks permissions, validates input, executes
database operations and returns rendered pages or CSV files.

**What are the main backend files?**

- `app.py`: routes, login, CRUD, attendance, exams, fees and reports.
- `db.py`: connection, queries, execution and transaction helpers.
- `catalog.py`: metadata used by the reusable master-data screens.

**How does login work?**

The backend finds the username with a parameterized query and compares the
submitted password with its stored password hash. It stores the user ID in a
four-hour session.

**How are roles enforced?**

A route decorator checks the current user's role before it runs the page.
Student, faculty and HOD routes also filter records to the user's identity,
assigned offering or department.

**What backend security exists?**

Password hashing, CSRF tokens, parameterized SQL, role checks, login throttling,
HTML escaping, a one-megabyte request limit and browser security headers.

## Database design

The 21 tables are grouped as follows:

- Academic: department, programme, course, programme_course, faculty, semester.
- People: student, guardian, student_guardian.
- Teaching: course_offering, registration, class_session, attendance.
- Results: examination, exam_result, grade_scale, grade.
- Fees: fee_bill, payment.
- Access: app_user, audit_event.

The four views are `v_academic_history`, `v_attendance_summary`,
`v_result_analysis` and `v_fee_balance`.

## Normalization questions

**What is normalization?**

Normalization organizes data into related tables to reduce repetition and
prevent insert, update and delete anomalies.

**What is First Normal Form?**

Every field contains one atomic value, and rows are uniquely identifiable. A
student has one registration number per row. Multiple guardians, payments,
results and attendance events are separate rows rather than comma-separated
lists.

**What is Second Normal Form?**

The database is in 1NF, and every non-key column in a table with a composite key
depends on the complete key. For example, Attendance uses
`registration_id + session_id`; `attendance_status` describes that exact
student-session pair. Programme Course uses `programme_id + course_id`, and its
term and course type describe the complete combination.

**What is Third Normal Form?**

The database is in 2NF, and non-key columns do not depend on other non-key
columns. Student stores `programme_id` but does not repeat programme or
department names. Course Offering stores the IDs of Course, Semester and
Faculty but does not copy their descriptive fields. Payment stores `bill_id`
and does not repeat student information.

**Why is the schema in 3NF?**

Each table stores one subject. Repeated events use separate rows, many-to-many
relationships use bridge tables, and calculated values such as balances and
attendance percentages come from views.

**What anomalies does normalization prevent?**

- Update anomaly: changing a department name in one place updates every join.
- Insert anomaly: a department can exist before it has students.
- Delete anomaly: deleting one student does not delete the programme definition.

**What are the bridge tables?**

`student_guardian`, `programme_course`, `registration`, `attendance` and
`exam_result` resolve many-to-many relationships.

**Why are Course and Course Offering separate?**

Course is a reusable catalogue item. Course Offering is one section of that
course in a specific semester, taught by a faculty member with a capacity.

## Keys and integrity questions

**What is a primary key?**

A column or combination of columns that uniquely identifies a row, such as
`student_id` or `registration_id + session_id`.

**What is a foreign key?**

A column that references a primary key in another table. For example,
`student.programme_id` references `programme.programme_id`.

**What are examples of unique business keys?**

Registration number, programme code, course code, employee number, bill number,
receipt number and username.

**What is referential integrity?**

Foreign keys prevent child rows from referring to missing parents. MySQL also
prevents deleting a department while programmes, courses or faculty still use
it.

**Why use composite keys?**

They prevent duplicate pairs. One registration can have only one attendance
row for one session and one result for one examination.

## Procedures, triggers and transactions

Three main procedures handle registration, dropping a registration and payment
collection. They check rules and use transactions.

Triggers verify that attendance belongs to the correct offering, marks do not
exceed maximum marks, examination dates are inside the semester, capacity does
not fall below enrolment and important identifiers are not changed after use.

A transaction treats several operations as one unit. It commits all changes on
success and rolls them back on error. `SELECT FOR UPDATE` locks the relevant row
so two simultaneous users cannot take the final seat or overpay the same bill.

## Live insert and delete

Safe SQL example using a temporary department with no child records:

```sql
INSERT INTO department (department_code, department_name)
VALUES ('DEMO-AI', 'Artificial Intelligence');

SELECT * FROM department WHERE department_code = 'DEMO-AI';

DELETE FROM department WHERE department_code = 'DEMO-AI';
```

The same demonstration can be performed through the Departments page. Add the
temporary code and name, confirm that it appears, click Delete, and confirm that
it has disappeared. The database count changes from 11 to 12 and back to 11.

Run `Presentation/START_PRESENTATION.ps1`. Enter a department through the
website, then run this in the database console:

```sql
SELECT department_id, department_code, department_name
FROM department
ORDER BY department_id DESC
LIMIT 10;
```

Delete the demonstration department through the website while it has no child
records, then run the same query again. Explain that both actions changed the
same MySQL table.

For a relational demonstration, add a faculty member under an existing
department and run:

```sql
SELECT f.employee_no, f.full_name,
       d.department_code, d.department_name
FROM faculty AS f
JOIN department AS d ON d.department_id = f.department_id
ORDER BY f.faculty_id DESC
LIMIT 10;
```

## Record-count question from the audio

The presentation database contains at least eleven synthetic records in every
one of its 21 base tables. Run the count query in `Live_Demo_Queries.sql` to show
all table names and record counts together.

## Testing questions

**How was the project tested?**

With pytest, Flask's test client and a separate real MySQL database named
`college_test`. The tests do not reset the presentation database.

**What was the result?**

45 tests passed, with zero failures and zero errors.

**What areas were tested?**

- Every administrator screen renders.
- Six roles receive allowed pages and receive 403 for forbidden pages.
- Faculty, student and HOD record isolation.
- Login, CSRF rejection and SQL-injection resistance.
- Student create, read, update and delete, including safe HTML escaping.
- Duplicate and ineligible registration rejection.
- Concurrent competition for the last seat.
- Registration drops and capacity release.
- Payment amount, duplicate receipt and concurrent overpayment protection.
- Attendance session/registration validation.
- Result pairing and maximum-mark validation.
- Grade publication rollback and grade locking.
- Foreign keys, unique codes and capacity constraints.
- Six CSV report exports.
- Fee-bill and payment UI workflow.
- Guardian links and role-account creation.

**What is a positive test?**

A valid action succeeds, such as creating a fee bill and recording a payment.

**What is a negative test?**

An invalid action fails safely, such as entering marks above the maximum or
accessing another student's page.

**What is a concurrency test?**

Two operations run at nearly the same time. The project verifies that only one
student receives the final seat and two payments cannot exceed a bill balance.

## Team-contribution answer

Use only after each member has actually completed or reviewed the assigned work.

- Golamari Shashanth Reddy: requirements, database setup, SQL queries,
  integration, GitHub and final coordination.
- Hansini Baggu: entities, ER diagrams, relational schema, normalization, data
  dictionary and report documentation.
- Kandibanda Balaji: UI review, CRUD workflows, test execution, screenshots,
  presentation and live demonstration.

Each collaborator should accept the GitHub invitation and create a genuine
commit from their own account. Use those individual commit URLs as evidence.

## Rapid viva questions

**Why MySQL?** It supports relational constraints, joins, views, triggers,
procedures and transactions.

**Why Flask?** It is a small Python web framework that fits this local academic
prototype and connects cleanly to MySQL.

**Why PyMySQL?** It is the Python database driver used to send parameterized SQL
to MySQL. It plays the connector role that JDBC plays in a Java application.

**What is a view?** A saved SELECT query that presents calculated or joined data
without storing another editable copy.

**What is a JOIN?** An operation that combines rows from related tables through
matching key values.

**What is an index?** A database structure that speeds up searches. The schema
indexes student names, registration rosters and fee due dates.

**Why use parameterized queries?** Values are sent separately from SQL syntax,
which prevents user input from changing the query structure.

**What is an audit log?** `audit_event` records the user, action, details and
time of successful changes.

**Where are balances stored?** They are calculated by `v_fee_balance` from fee
bills and payments.

**Where is attendance percentage stored?** It is calculated by
`v_attendance_summary`, after all held sessions have attendance entries.

**Can the project be used in production now?** No. It is a local academic
prototype with synthetic data and demonstration grading rules. Production use
would require institutional policy approval, managed hosting, HTTPS, backups,
monitoring and a stronger account lifecycle.
