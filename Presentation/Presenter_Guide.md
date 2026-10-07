# Ten-minute presentation guide

Use `Student_College_Management_Rubric_Complete.pptx` (or its PDF copy).
The slides follow the supplied brief's approximate 1 + 2 + 2 + 3 + 2 minute
structure. The exact date and slot must be confirmed with the faculty; the
supplied schedule lists this project at 9:00–9:10 a.m. on 6 October 2026.

| Time | Slides / action | Main point |
|---|---|---|
| 0:00–1:00 | 1–2 | Problem, objectives, scope and six user roles. |
| 1:00–3:00 | 3–5 | Four ER views, registration as the key bridge, PK/FK schema, 3NF. |
| 3:00–5:00 | 6–7 | Show the SQL script, 21-table row counts, a join, an aggregate and a fee-balance query. |
| 5:00–8:00 | 8–9 and live app | Log in; show department count 11, insert DEMO-QA, confirm 12 in UI and MySQL, delete, confirm 11. Show student, attendance, grades and fees if time. |
| 8:00–10:00 | 10 | Summarize verification and answer questions. |

The live demo commands and login are in `DEMO_RUNBOOK.md`. If the database is
already initialized, use `SHOW CREATE TABLE` and the saved fresh-import output
to explain creation rather than resetting the running demo database. For a
fresh live creation, import `DBMS_Course_Project_All_Commands.sql` into a new
project instance before opening the UI.

Questions to prepare for:

- **Why Course Offering?** A catalogue course can recur in semesters and have
  multiple sections, teachers and capacities.
- **Why Registration?** It resolves Student–Offering many-to-many and anchors
  attendance, exam results and grades to an actual enrolment.
- **Why 3NF?** Student, course, department and fee facts live in separate
  tables; non-key attributes depend on their table's key.
- **How are rules enforced?** Primary/foreign keys, unique/check constraints,
  transactional procedures and UI validation protect data.
- **What is the scope?** Local academic prototype with synthetic records;
  library, hostel, payroll and production deployment are future work.

All three members should present only the parts they actually worked on.
Complete the contribution placeholders in the report and GitHub repository
before submission.
