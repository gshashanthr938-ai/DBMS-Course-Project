# Campus Ledger

Campus Ledger is the complete implementation of DBMS Project 01, the Student and College Management System. It uses Python, Flask and MySQL 8 and includes role-based screens for admissions, course registration, attendance, examinations, grades, fee bills, payments and reports.

## What is included

- 21 relational tables in Third Normal Form, including the 13 principal entities required by the brief
- foreign keys, unique keys, checks, indexes, triggers and transaction-safe stored procedures
- synthetic sample data for 12 students, five course sections, attendance, examinations and fee records
- administrator, faculty, examination, accounts, student and head-of-department roles
- six live reports with CSV export
- 45 automated tests against an isolated MySQL test database
- final presentation, report and screenshots in the parent folders

## First-time setup

1. Install MySQL 8 and Python 3.12 or later.
2. Open PowerShell in this folder.
3. Run `powershell -ExecutionPolicy Bypass -File .\start.ps1`.

The script creates a project-only MySQL data directory on port 3308, installs the Python packages into `.venv`, imports the complete presentation database with at least five rows per table, and opens the application at `http://127.0.0.1:5080`.

The setup never drops or edits an existing college-management database. Test runs use a separate `college_test` database. The project-only database files and passwords stay under `.local`, which is excluded from Git.

## Demonstration accounts

See [DEMO_ACCOUNTS.md](DEMO_ACCOUNTS.md). All provided demo accounts use `CollegeDemo!2026`. Change or remove demonstration credentials before any real deployment.

## Review demonstration

Use [DEMONSTRATION_GUIDE.md](DEMONSTRATION_GUIDE.md) for a short sequence covering admission, registration, attendance, grade processing, fee collection, reports, validation and role isolation.

## Database files

Run the scripts in this order for a manual empty-database installation:

1. `sql/01_schema.sql`
2. `sql/02_routines.sql`
3. `sql/03_views_reports.sql`
4. `sql/04_sample_data.sql`

The parent folder's `DBMS_Course_Project_All_Commands.sql` combines these scripts and the five-row supplement. `setup_presentation.py` is the first-run installer because it also creates the restricted application account. `setup.py` is retained for isolated test database setup. All contacts are synthetic `example.test` records.

## Tests

Run:

```powershell
.\.venv\Scripts\python.exe -m pytest tests -q
```

The suite recreates only `college_test`. It checks page rendering, permissions, CSRF protection, SQL injection resistance, CRUD, cross-section duplicates, capacity races, payment races, attendance validity, result validity, grade publication, foreign keys and CSV exports.

## Backup

Run `powershell -ExecutionPolicy Bypass -File .\backup.ps1`. It creates a timestamped SQL dump under `.local\backups`. The dump contains the database contents and should be protected if real data is ever used.

## Scope and policy assumptions

The implementation covers the requested first version. It deliberately omits hostel, library, transport, payroll, payment-gateway processing, automatic timetabling, refunds, retests and curriculum versioning.

The sample attendance threshold of 75%, grade scale and treatment of an absent exam as zero are demonstration rules. The interface labels them clearly; they must be replaced with the institution's approved policy before real use.

This is a local academic prototype. A production deployment also needs HTTPS, managed secrets, database backups, monitoring, password reset, account lockout, institutional privacy review and an approved retention policy.
