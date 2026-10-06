# Live MySQL and UI demonstration

## On this presentation computer

1. Run `UI-Source/start.ps1` in PowerShell. On a fresh checkout, it creates a
   private MySQL 8 database named `college_pbl_presentation`, imports the full
   21-table SQL script with at least five rows per table, saves local credentials
   in ignored `UI-Source/.local`, and opens `http://127.0.0.1:5080`.
2. Sign in with the local synthetic demo account in
   `UI-Source/DEMO_ACCOUNTS.md` (admin is easiest for the review).
3. Keep `DBMS_Course_Project_All_Commands.sql`, `Live_Demo_Queries.sql`,
   `SQL_Execution_Output.txt`, the slides and this guide open.

This setup expects Python 3, PowerShell and MySQL Server 8 at
`C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqld.exe`. The initial Python
environment may require package installation; prepare it before presenting.
The `.local` folder and `.venv` are intentionally excluded from GitHub.

## Two-minute SQL segment

Use MySQL Workbench or the MySQL command-line client connected to the private
server at `127.0.0.1:3308`, with the root password stored locally in
`UI-Source/.local/admin.json`. Do not project the password or this JSON file.
The complete creation/import script is provided separately so the examiner can
see every `CREATE TABLE`, key, constraint, insert, view and procedure. Its
successful execution and query outputs are in `SQL_Execution_Output.txt`.

Run these read-only statements against the already seeded demo database:

```sql
USE college_pbl_presentation;
SHOW CREATE TABLE registration;
SELECT COUNT(*) AS students FROM student;
SELECT COUNT(*) AS departments FROM department;
SELECT s.registration_no, s.full_name, c.course_code
FROM student s
JOIN registration r ON r.student_id = s.student_id
JOIN course_offering o ON o.offering_id = r.offering_id
JOIN course c ON c.course_id = o.course_id
LIMIT 5;
SELECT c.course_code, COUNT(*) AS enrolments
FROM registration r
JOIN course_offering o ON o.offering_id = r.offering_id
JOIN course c ON c.course_id = o.course_id
GROUP BY c.course_code;
```

For a fresh live creation, use a newly initialized private project database
and run `DBMS_Course_Project_All_Commands.sql` once. It already includes
creation, insertions, counts, joins and aggregate queries. Do not rerun it on
the active database: the script intentionally refuses duplicate tables.

## Three-minute UI segment

1. Open **Departments** as admin: the starting count is five.
2. Add department code `DEMO-QA` and name `Quality Assurance Demo`.
3. Refresh the UI and run `SELECT COUNT(*) FROM department;` in MySQL: both
   show six, including `DEMO-QA`.
4. Delete that demonstration department and repeat the count: both show five;
   `SELECT * FROM department WHERE department_code='DEMO-QA';` returns none.
5. Open **Students**, **Attendance**, **Examinations**, **Fees** and **Reports**
   to show the wider system if time permits.

The before/after screenshots are in `screenshots/13–15`, and the exact
database observations are in `CRUD_Database_Evidence.txt`. If another demo
already changed records, use a new code and describe the actual counts.

## Before submission

- Fill in the team/course/faculty/year, real contributions and GitHub fields
  listed in `../Project-Report/REPORT_FIELDS_TO_COMPLETE.md`.
- Add both teammates as collaborators to the public `DBMS-Course-Project`
  repository and have each person commit from their own account.
- Upload the repository folders exactly as supplied here and paste its URL in
  the README and report appendix.
- Confirm the presentation date/slot with the faculty: the supplied PDF has a
  6 October 2026 schedule, which may differ from the spoken plan.
