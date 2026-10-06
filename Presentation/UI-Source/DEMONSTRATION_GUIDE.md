# Review 3 Demonstration Guide

## Prepare

Run `start.ps1`, open `http://127.0.0.1:5080`, and sign in as `admin` with the password in `DEMO_ACCOUNTS.md`.

## Eight-minute demonstration

1. On Overview, explain that the four figures come from the live database. Open the attendance alert or result report to show actionable records.
2. Open Students and search for `2026CS001`. Show the connected programme, guardians, course history, attendance, examination results and fee bills.
3. Create a new admission with a new registration number. Link a guardian. Explain the unique registration-number check.
4. Open Registrations and register the new student in an eligible section. Attempting the same course in another section of the same semester is rejected. Capacity is checked inside a database transaction.
5. Open Attendance, select a course section and a held session, then mark Present or Absent. Explain that blank means unmarked, not absent.
6. Open Examinations and grades. Show a scored result, an explicit absence and a pending result. Explain that pending results block final grade publication and marks above the exam maximum are rejected.
7. Open Fees and payments. Show partial payments and the current balance. Entering more than the remaining balance is rejected; the stored procedure locks the bill during the check.
8. Open Reports and export a CSV. Switch to the `student` account and show that the student can see only their own record. Switch to `faculty` to show only assigned sections.

## Validation examples for viva

| Rule | Demonstration |
|---|---|
| Unique registration number | Try to admit a second student with `2026CS001`. |
| No duplicate course registration | Try to register one student for DBMS sections A and B in the same semester. |
| Section capacity | Fill the small DBMS B section and try one additional registration. |
| Valid attendance | Attendance can be entered only for a matching registration and held session. |
| Valid marks | Enter 51 for the Internal examination whose maximum is 50. |
| Complete grade record | Try publishing DBMS A while one result is pending. |
| Payment limit | Try paying more than the displayed balance. |
| Referential integrity | Try deleting a department used by a programme. |
| Role isolation | A student cannot open another student's URL; faculty cannot open accounts. |

## Expected report evidence

- Academic history joins Student, Registration, CourseOffering, Course, Semester and Grade.
- Course registration shows current active rosters and section occupancy.
- Attendance shortage separates present, absent and unmarked sessions.
- Result analysis shows entered, absent and pending counts plus average and highest marks.
- Fee dues derives the balance from bills and payments.
- Department summary includes departments and programmes even when they have no students.

## Questions to expect

**Why is CourseOffering separate from Course?** A course is the reusable catalogue definition. An offering is one section of that course in one actual semester with one teacher and capacity.

**Why does Attendance reference Registration?** It proves the student was registered for that exact course offering when the class was held.

**Why is ExamResult separate from Grade?** ExamResult records every component assessment. Grade is the single finalized course outcome.

**How are race conditions handled?** Registration locks the offering before counting active seats. Payment locks the bill before calculating its remaining balance. Concurrent requests therefore cannot both consume the last seat or overpay a bill.

**Is the database in 3NF?** Each table represents one subject; non-key attributes depend on its key and not on another non-key attribute. Many-to-many relationships use associative tables. Calculated balances and attendance percentages are views rather than stored copies.
