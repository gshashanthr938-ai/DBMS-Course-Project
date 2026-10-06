# Fields to complete before submission

The PDF intentionally shows placeholders for details that the team said it
would provide later. Replace them in the final submitted report and README:

| Field | Where |
|---|---|
| Course name and code | Cover page, README |
| Faculty guide | Cover page, README |
| Academic year | Cover page, README |
| Actual work by each member | Report section 16 and `CONTRIBUTIONS_TO_COMPLETE.md` |
| Three GitHub usernames and real commit links | Report sections 16–17 and contribution file |
| Public repository URL | Report appendix and README |
| Confirmed presentation date and slot | Presenter guide / slide title if needed |

The report contains the project content, schema, data dictionary, actual SQL
outputs, screenshots, implementation, test results and references. Do not
replace the contribution placeholders with invented assignments.

Edit `report_metadata.json`, then run `build_final_report.py` to rebuild the
submission PDF from the local running demonstration database. The builder uses
ReportLab and PyMySQL. The other narrative text can be edited in the builder.
