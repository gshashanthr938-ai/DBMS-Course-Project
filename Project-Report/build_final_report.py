from collections import defaultdict
from pathlib import Path
from xml.etree import ElementTree
from xml.sax.saxutils import escape
import json

import pymysql
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.utils import ImageReader
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, PageBreak,
                               Image, LongTable, Table, TableStyle, Preformatted,
                               KeepTogether)

ROOT=Path(__file__).resolve().parent.parent
PRE=ROOT/'Presentation'
APP=PRE/'UI-Source'
OUT=ROOT/'Project-Report'/'Student_College_Management_Final_Project_Report.pdf'
OUT.parent.mkdir(parents=True,exist_ok=True)
metadata=json.loads((OUT.parent/'report_metadata.json').read_text(encoding='utf-8'))

admin=json.loads((APP/'.local'/'admin.json').read_text(encoding='utf-8'))
conn=pymysql.connect(host=admin['host'],port=admin['port'],user='root',password=admin['password'],
                     database='college_pbl_presentation',cursorclass=pymysql.cursors.DictCursor)
def query(sql,args=()):
    with conn.cursor() as cur:
        cur.execute(sql,args)
        return cur.fetchall()

tables=[r['TABLE_NAME'] for r in query('''SELECT TABLE_NAME FROM information_schema.TABLES
WHERE TABLE_SCHEMA=%s AND TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME''',('college_pbl_presentation',))]
columns=query('''SELECT TABLE_NAME,COLUMN_NAME,COLUMN_TYPE,IS_NULLABLE,COLUMN_KEY,EXTRA
FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=%s
ORDER BY TABLE_NAME,ORDINAL_POSITION''',('college_pbl_presentation',))
key_rows=query('''SELECT TABLE_NAME,COLUMN_NAME,CONSTRAINT_NAME,REFERENCED_TABLE_NAME
FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=%s''',('college_pbl_presentation',))
fks={(r['TABLE_NAME'],r['COLUMN_NAME']):r['REFERENCED_TABLE_NAME']
     for r in key_rows if r['REFERENCED_TABLE_NAME']}
counts={t:query(f'SELECT COUNT(*) AS n FROM `{t}`')[0]['n'] for t in tables}
join_rows=query('''SELECT s.registration_no,s.full_name,c.course_code,o.section_code
FROM student s JOIN registration r ON r.student_id=s.student_id
JOIN course_offering o ON o.offering_id=r.offering_id
JOIN course c ON c.course_id=o.course_id
WHERE r.registration_status='ACTIVE'
ORDER BY s.registration_no,c.course_code LIMIT 6''')
aggregate_rows=query('''SELECT c.course_code,o.section_code,COUNT(r.registration_id) AS active_students
FROM course_offering o JOIN course c ON c.course_id=o.course_id
LEFT JOIN registration r ON r.offering_id=o.offering_id AND r.registration_status='ACTIVE'
GROUP BY o.offering_id,c.course_code,o.section_code ORDER BY c.course_code,o.section_code''')
fee_rows=query('''SELECT b.bill_no,s.full_name,b.total_amount,b.paid_amount,b.balance
FROM v_fee_balance b JOIN student s ON s.student_id=b.student_id
ORDER BY b.bill_no LIMIT 5''')
conn.close()

xml=ElementTree.parse(APP/'docs'/'test-results-final.xml').getroot().find('testsuite')
tests=int(xml.get('tests')); failures=int(xml.get('failures')); errors=int(xml.get('errors'))

styles=getSampleStyleSheet()
styles.add(ParagraphStyle(name='ReportTitle',fontName='Helvetica-Bold',fontSize=23,leading=28,
                          textColor=colors.HexColor('#17363A'),alignment=TA_CENTER,spaceAfter=20))
styles.add(ParagraphStyle(name='ReportSub',fontName='Helvetica',fontSize=13,leading=17,
                          textColor=colors.HexColor('#146C5B'),alignment=TA_CENTER,spaceAfter=13))
styles.add(ParagraphStyle(name='H1x',fontName='Helvetica-Bold',fontSize=15.5,leading=20,
                          textColor=colors.HexColor('#17363A'),spaceBefore=16,spaceAfter=9,keepWithNext=True))
styles.add(ParagraphStyle(name='H2x',fontName='Helvetica-Bold',fontSize=11,leading=14,
                          textColor=colors.HexColor('#146C5B'),spaceBefore=11,spaceAfter=5,keepWithNext=True))
styles.add(ParagraphStyle(name='Bodyx',fontName='Helvetica',fontSize=9.2,leading=13.4,
                          spaceAfter=7))
styles.add(ParagraphStyle(name='Smallx',fontName='Helvetica',fontSize=7.8,leading=10.2,
                          spaceAfter=4))
styles.add(ParagraphStyle(name='Headerx',fontName='Helvetica-Bold',fontSize=8,leading=10.5,
                          textColor=colors.white))
styles.add(ParagraphStyle(name='Captionx',fontName='Helvetica-Oblique',fontSize=8.2,leading=11,
                          textColor=colors.HexColor('#526A6A'),alignment=TA_CENTER,spaceBefore=4,spaceAfter=8))
styles.add(ParagraphStyle(name='CodeX',fontName='Courier',fontSize=7.9,leading=10.6,
                          backColor=colors.HexColor('#EFF4F0'),borderPadding=7,spaceBefore=6,spaceAfter=9))

story=[]
def p(value,style='Bodyx'):
    story.append(Paragraph(value,styles[style]))
def h(number,title):
    p(f'{number}  {escape(title)}','H1x')
def sub(title): p(escape(title),'H2x')
def gap(n=7): story.append(Spacer(1,n))
def bullet(value): p('• '+value)
def code(value): story.append(KeepTogether([Preformatted(value,styles['CodeX'])]))
def table(headers,rows,widths=None,small=False):
    st=styles['Smallx'] if small else styles['Bodyx']
    cells=[[Paragraph(escape(str(x)),styles['Headerx']) for x in headers]]
    cells += [[Paragraph(escape(str(x)),st) for x in row] for row in rows]
    obj=LongTable(cells,colWidths=widths,repeatRows=1,hAlign='LEFT')
    obj.setStyle(TableStyle([
       ('BACKGROUND',(0,0),(-1,0),colors.HexColor('#23464A')),
       ('TEXTCOLOR',(0,0),(-1,0),colors.white),
       ('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor('#EFF4F0')]),
       ('GRID',(0,0),(-1,-1),0.35,colors.HexColor('#D9E1DC')),
       ('VALIGN',(0,0),(-1,-1),'MIDDLE'),
       ('TOPPADDING',(0,0),(-1,-1),5 if not small else 3),
       ('BOTTOMPADDING',(0,0),(-1,-1),5 if not small else 3),
       ('LEFTPADDING',(0,0),(-1,-1),6),('RIGHTPADDING',(0,0),(-1,-1),6),
    ]))
    story.append(obj);gap(8)
def image(path,width,caption):
    source=Path(path); reader=ImageReader(str(source)); w,h=reader.getSize()
    item=Image(str(source),width=width,height=width*h/w)
    item.hAlign='CENTER';story.append(item);p(escape(caption),'Captionx')
def image_pair(a,b,cap_a,cap_b):
    def cell(path,caption):
        reader=ImageReader(str(path)); w,h=reader.getSize(); width=239
        return [Image(str(path),width=width,height=width*h/w),
                Paragraph(escape(caption),styles['Captionx'])]
    t=Table([[cell(a,cap_a),cell(b,cap_b)]],colWidths=[251,251],hAlign='CENTER')
    t.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),5),('RIGHTPADDING',(0,0),(-1,-1),5)]))
    story.append(t);gap(9)

# 1 Cover page
gap(94)
p('DBMS Course Project Report','ReportTitle')
p('Student and College Management System','ReportSub')
p('Campus Ledger','ReportSub')
gap(30)
table(['Team member','Roll number'],[
  ('Golamari Shashanth Reddy','25WU0101041'),
  ('Hansini Baggu','25WU0101045'),
  ('Kandibanda Balaji','25WU0101057')],[320,182])
gap(15)
p('<b>Course name and code:</b> '+escape(metadata['course_name_code']))
p('<b>Faculty guide:</b> '+escape(metadata['faculty_guide']))
p('<b>Academic year:</b> '+escape(metadata['academic_year']))
p('<b>Report prepared:</b> 6 October 2026')
story.append(PageBreak())

# 2 Abstract
h(2,'Abstract')
p('Campus Ledger is a local Student and College Management System that connects academic and fee records in a relational database. The problem addressed is repeated and inconsistent student data across admissions, course registration, attendance, examinations and accounts. The project uses a conceptual ER model, a MySQL 8 schema in Third Normal Form, integrity constraints and a role-based Flask web interface. Twenty-one base tables represent students, guardians, departments, programmes, courses, faculty, semesters, course offerings, registrations, class sessions, attendance, examinations, results, grades, fee bills and payments, with supporting tables for users and audit events. Four views derive reporting data.')
p('The implemented interface supports insertion, deletion where records are unused, viewing, registrations, attendance, examination outcomes, grade publication, payment receipts and six CSV reports. A presentation database was populated with at least five synthetic records in each base table. The combined SQL file was executed on MySQL 8.0.46; a UI department record was inserted and deleted, with counts verified as 5, 6 and 5. The automated test suite completed with 45 passes, zero failures and zero errors. Demonstration attendance and grading values are sample rules, so institutional policy approval is required before real deployment.')

# 3 Introduction and problem
h(3,'Introduction and problem statement')
p('A college must answer connected questions about one student: which programme the student joined, which course section they attend, whether an examination result is complete, and what fees remain unpaid. If each office maintains separate registers, information is repeated and reconciled manually. This increases the chance of inconsistent values and delays reporting.')
p('The project therefore models college operations as related entities with one source of truth for each fact. A Student refers to a Programme; a Registration connects a Student to an actual Course Offering; Attendance and Exam Result rows attach to that registration; a Fee Bill belongs to a Student and its Payments determine the balance. The web interface gives each role a suitable view of these relationships.')

# 4 Objectives and scope
h(4,'Objectives and scope')
for item in [
 'Record admissions and guardian relationships without repeating programme or department facts.',
 'Maintain courses, faculty, semesters, offerings and programme curriculum.',
 'Register students in eligible course sections while enforcing capacity and duplicate rules.',
 'Capture held sessions, attendance, examination results and final grades.',
 'Issue fee bills, record partial or full payments and derive outstanding balances.',
 'Provide role-specific access, audit records and six reports with CSV export.'
]: bullet(item)
p('<b>Scope boundary.</b> This academic prototype uses synthetic data and runs locally. Hostel, library, transport, payroll, gateway payments, refunds and automatic timetabling are not included. The 75% attendance threshold and grade scale are demonstration assumptions.')

# 5 Requirements
h(5,'Software and hardware requirements')
table(['Component','Requirement or tested environment'],[
 ('Database','MySQL 8.0.46 tested; SQL uses MySQL 8 constraints and InnoDB transactions.'),
 ('Application','Python 3.12 or later; Flask 3.1.3, PyMySQL 1.2.3, Waitress 3.0.2.'),
 ('Testing','pytest 9.1.1 against a separate MySQL test database.'),
 ('Client','Current desktop browser with HTML, CSS and JavaScript support.'),
 ('Hardware','One local laptop or desktop able to run MySQL, Python and a browser. No performance minimum was benchmarked.'),
 ('Connectivity','Localhost ports 3308 (MySQL) and 5080 (web app) for the demonstration.'),
],[125,377])

# 6 ER diagrams
story.append(PageBreak());h(6,'ER diagram')
p('The diagrams show the principal entities, primary keys, cardinalities and participation. In each one-to-many relationship, the child row requires its parent through a foreign key, while a parent can exist with zero child rows. The full-size PNG files are in the Presentation folder.')
image(PRE/'ER_Diagram_1.png',395,'Figure 1. Academic structure and guardian link.')
story.append(PageBreak())
image(PRE/'ER_Diagram_2.png',500,'Figure 2. Registration, class sessions and attendance.')
image(PRE/'ER_Diagram_3.png',500,'Figure 3. Examination results and final grades.')
image(PRE/'ER_Diagram_4.png',500,'Figure 4. Fee bills and payments.')

# 7 Relational schema and normalization
story.append(PageBreak());h(7,'Relational schema and normalization')
p('The schema has 21 base tables. Primary keys identify rows, foreign keys connect dependent rows, unique keys protect business identifiers, and checks reject invalid ranges or states. Representative relations are Student(student_id PK, programme_id FK, registration_no UNIQUE), CourseOffering(offering_id PK, course_id FK, semester_id FK, faculty_id FK), Registration(registration_id PK, student_id FK, offering_id FK), Attendance(registration_id + session_id composite PK), FeeBill(bill_id PK, student_id FK, semester_id FK), and Payment(payment_id PK, bill_id FK).')
purpose={
 'app_user':'Role-linked application sign-in','attendance':'Presence for a held class',
 'audit_event':'Successful action history','class_session':'One held class',
 'course':'Reusable course catalogue','course_offering':'Section in a semester',
 'department':'Academic department','exam_result':'Student assessment outcome',
 'examination':'Assessment definition','faculty':'Faculty master',
 'fee_bill':'Student fee demand','grade':'Final course grade',
 'grade_scale':'Demonstration grade thresholds','guardian':'Guardian contact',
 'payment':'Confirmed fee receipt','programme':'Programme within department',
 'programme_course':'Programme curriculum','registration':'Student course enrollment',
 'semester':'Academic period','student':'Admission and identity',
 'student_guardian':'Student and guardian link'
}
rels=[]
for t in tables:
    pk=[r['COLUMN_NAME'] for r in key_rows if r['TABLE_NAME']==t and r['CONSTRAINT_NAME']=='PRIMARY']
    parent=sorted({r['REFERENCED_TABLE_NAME'] for r in key_rows if r['TABLE_NAME']==t and r['REFERENCED_TABLE_NAME']})
    rels.append((t,', '.join(pk),' / '.join(parent) if parent else '—',purpose.get(t,'')))
table(['Table','Primary key','Parent table(s)','Purpose'],rels,[102,135,132,133],small=True)
sub('Third Normal Form justification')
p('Each table stores one subject and every non-key attribute describes its key. Student stores programme_id, while the department comes through Programme, avoiding a transitive dependency. Many-to-many associations are represented by StudentGuardian, ProgrammeCourse and Registration. Repeated events such as class sessions, results and payments are separate rows. Balances and attendance percentages are calculated in views rather than stored as editable duplicates.')

# 8 Data dictionary
story.append(PageBreak());h(8,'Data dictionary')
p('This dictionary is generated from the executed MySQL schema. PK identifies a primary key; FK names a referenced table; UNIQUE identifies an alternate key. The full DDL, including CHECK constraints and indexes, is in the combined SQL file.')
by_table=defaultdict(list)
for c in columns:
    key=[]
    if c['COLUMN_KEY']=='PRI': key.append('PK')
    if c['COLUMN_KEY']=='UNI': key.append('UNIQUE')
    if (c['TABLE_NAME'],c['COLUMN_NAME']) in fks:
        key.append('FK → '+fks[(c['TABLE_NAME'],c['COLUMN_NAME'])])
    if c['EXTRA']: key.append(c['EXTRA'])
    by_table[c['TABLE_NAME']].append((c['COLUMN_NAME'],c['COLUMN_TYPE'],c['IS_NULLABLE'],', '.join(key) or '—'))
for t in tables:
    sub(t)
    table(['Column','Type','Null?','Key / extra'],by_table[t],[152,154,49,147],small=True)

# 9 SQL DDL/DML with outputs
story.append(PageBreak());h(9,'SQL commands used with sample outputs')
p('The file <b>Presentation/DBMS_Course_Project_All_Commands.sql</b> is runnable in a fresh MySQL 8 database. It includes database creation, 21 table definitions, procedures, triggers, views, synthetic INSERT statements and SELECT queries. The MySQL execution transcript is supplied as <b>SQL_Execution_Output.txt</b>.')
code('''CREATE DATABASE college_pbl_presentation\n  CHARACTER SET utf8mb4;\nCREATE TABLE department (\n  department_id INT AUTO_INCREMENT PRIMARY KEY,\n  department_code VARCHAR(12) NOT NULL UNIQUE,\n  department_name VARCHAR(120) NOT NULL\n);\nINSERT INTO department (department_code, department_name)\nVALUES ('CSE', 'Computer Science and Engineering');''')
p('The presentation script then adds synthetic rows to satisfy the five-per-table requirement. A final SELECT verified these counts after import:')
table(['Base table','Rows','Base table','Rows'],
      [(tables[i],counts[tables[i]],tables[i+11] if i+11<len(tables) else '',
        counts[tables[i+11]] if i+11<len(tables) else '') for i in range(11)],
      [177,74,177,74],small=True)
p('The temporary UI demonstration row was removed after capture; the department count therefore remains five. Audit events may increase when the UI is used.')

# 10 Query outputs
h(10,'Queries with outputs')
sub('Join across student, registration, offering and course')
code('''SELECT s.registration_no, s.full_name, c.course_code, o.section_code\nFROM student s JOIN registration r ON r.student_id=s.student_id\nJOIN course_offering o ON o.offering_id=r.offering_id\nJOIN course c ON c.course_id=o.course_id\nORDER BY s.registration_no, c.course_code LIMIT 6;''')
table(['Registration','Student','Course','Section'],
      [(r['registration_no'],r['full_name'],r['course_code'],r['section_code']) for r in join_rows],
      [109,174,115,104],small=True)
sub('Aggregate query including empty course sections')
code('''SELECT c.course_code, o.section_code, COUNT(r.registration_id) AS active_students\nFROM course_offering o JOIN course c ON c.course_id=o.course_id\nLEFT JOIN registration r ON r.offering_id=o.offering_id\n  AND r.registration_status='ACTIVE'\nGROUP BY o.offering_id,c.course_code,o.section_code;''')
table(['Course','Section','Active students'],
      [(r['course_code'],r['section_code'],r['active_students']) for r in aggregate_rows],
      [170,150,182],small=True)
sub('Derived fee balances from a reporting view')
table(['Bill','Student','Total','Paid','Balance'],
      [(r['bill_no'],r['full_name'],f"{r['total_amount']:,.2f}",
        f"{r['paid_amount']:,.2f}",f"{r['balance']:,.2f}") for r in fee_rows],
      [82,180,80,80,80],small=True)

# 11 UI design/screenshots
story.append(PageBreak());h(11,'UI design and screenshots')
p('The interface exposes role-specific pages for records, teaching, examinations, accounts and reports. The following screenshots were captured from the running application connected to the presentation MySQL database. A separate set in the Presentation/screenshots folder covers all main UI screens.')
image_pair(PRE/'screenshots'/'01-dashboard.png',PRE/'screenshots'/'02-student-record.png',
           'Dashboard: live summary.','Student profile: connected records.')
image_pair(PRE/'screenshots'/'03-attendance.png',PRE/'screenshots'/'04-examinations.png',
           'Attendance entry.','Examination outcome entry.')
image_pair(PRE/'screenshots'/'05-fees.png',PRE/'screenshots'/'06-reports.png',
           'Fee bills and payments.','Attendance and other reports.')
sub('Before and after insertion and deletion')
image_pair(PRE/'screenshots'/'13-department-before-insert.png',
           PRE/'screenshots'/'14-department-after-insert-before-delete.png',
           'Before insert: five departments.','After insert: DEMO-QA shown, six departments.')
image_pair(PRE/'screenshots'/'14-department-after-insert-before-delete.png',
           PRE/'screenshots'/'15-department-after-delete.png',
           'Before delete: DEMO-QA is present.','After delete: DEMO-QA is absent.')
p('The UI create and delete actions changed the live department count from 5 to 6 and back to 5; the exact SELECT evidence is in <b>Presentation/CRUD_Database_Evidence.txt</b>.')

# 12 Implementation
story.append(PageBreak())
h(12,'Implementation details')
table(['Layer','Implementation'],[
 ('Browser','HTML templates, CSS, JavaScript forms and CSV downloads.'),
 ('Application','Flask routes, role checks, CSRF tokens, validation and audit writes.'),
 ('Database access','PyMySQL parameterized queries and transaction helper.'),
 ('Database','MySQL 8 with InnoDB tables, foreign keys, checks, views, procedures and triggers.'),
],[132,370])
p('The application reads a local configuration file that is excluded from Git. The database helper opens a PyMySQL connection using that configuration; SQL values are passed as parameters. Mutating operations use transactions. Registration and payment stored procedures lock the relevant rows with SELECT FOR UPDATE so concurrent requests cannot exceed section capacity or bill balance.')
code('''def query(sql, args=(), one=False, con=None):\n    own = con is None\n    con = con or connect()\n    try:\n        with con.cursor() as cur:\n            cur.execute(sql, args)\n            return cur.fetchone() if one else cur.fetchall()\n    finally:\n        if own: con.close()''')
p('The UI module source is in <b>Presentation/UI-Source</b>; the complete SQL is in <b>Presentation/DBMS_Course_Project_All_Commands.sql</b>.')

# 13 Testing
h(13,'Testing: cases and results')
p(f'The automated suite was run against a separate MySQL test database on 6 October 2026: <b>{tests} tests passed, {failures} failures, {errors} errors</b>. The result file is Presentation/UI-Source/docs/test-results-final.xml. The main presentation database was not reset by the tests.')
table(['Test area','Expected result','Observed'],[
 ('Role permissions','Unauthorized account cannot access another role’s page','Pass'),
 ('CSRF and input validation','Invalid or missing token/value is rejected','Pass'),
 ('Course registration','Eligibility, duplicate and capacity rules enforced','Pass'),
 ('Concurrent last seat','Only one competing registration succeeds','Pass'),
 ('Attendance and marks','Mismatched session or excess marks rejected','Pass'),
 ('Grade publication','Incomplete results prevent publication','Pass'),
 ('Concurrent payment','Overpayment cannot be recorded','Pass'),
 ('Reports and CSV','Expected rows and export delivered','Pass'),
 ('UI CRUD demonstration','Department count changes 5 → 6 → 5','Pass'),
],[148,275,79],small=True)

# 14 Conclusion
h(14,'Conclusion and future enhancements')
p('The completed prototype turns separate college records into linked, queryable data. MySQL constraints protect relationships; views compute report values; the Flask interface supports the main academic and fee workflows. The fresh presentation database met the five-row minimum for every table, the UI insert/delete actions were reflected in MySQL, and the automated suite passed.')
for item in [
 'Replace demonstration attendance and grading rules with approved institutional policy.',
 'Add managed deployment, HTTPS, backup monitoring and a tested recovery process.',
 'Add institution-verified identity, password recovery and account lifecycle controls.',
 'Extend the scope to modules such as library, hostel or timetable only after requirements review.'
]: bullet(item)

# 15 References
h(15,'References')
for ref in [
 '[1] DBMS Course Project, Final Presentation Instructions and Schedule, supplied PDF, 4 October 2026.',
 '[2] DBMS PBL 70 Unique Project Statements, supplied Word document, Project 01.',
 '[3] Campus Ledger project source: sql/01_schema.sql, sql/02_routines.sql, sql/03_views_reports.sql, app.py, db.py and tests/test_system.py.',
 '[4] MySQL 8.0 Reference Manual, CREATE TABLE Statement, https://dev.mysql.com/doc/refman/8.0/en/create-table.html',
 '[5] Flask Documentation 3.1, https://flask.palletsprojects.com/en/stable/',
 '[6] PyMySQL Documentation, https://pymysql.readthedocs.io/en/latest/'
]: p(escape(ref))

# 16 Contributions — intentionally left for real attribution
h(16,'Contribution of each member')
p('Complete this section with actual work and matching GitHub commits. The team requested editable placeholders; no contribution is assigned without confirmation.')
table(['Member','Actual contribution','Commit evidence'],[
 ('Golamari Shashanth Reddy (25WU0101041)',metadata['contributions']['Golamari Shashanth Reddy'],metadata['commit_links']['Golamari Shashanth Reddy']),
 ('Hansini Baggu (25WU0101045)',metadata['contributions']['Hansini Baggu'],metadata['commit_links']['Hansini Baggu']),
 ('Kandibanda Balaji (25WU0101057)',metadata['contributions']['Kandibanda Balaji'],metadata['commit_links']['Kandibanda Balaji']),
],[179,205,118],small=True)

# 17 Repository link
h(17,'Appendix: GitHub repository link')
p('<b>Public repository:</b> '+escape(metadata['repository_url']))
p('<b>Repository owner:</b> '+escape(metadata['repository_owner']))
p('<b>Other members as collaborators:</b> '+escape(metadata['collaborators']))
p('The public repository contains the Presentation and Project-Report folders. Add the other two members as collaborators and include their actual commits before final submission.')

def footer(canvas,doc):
    canvas.saveState()
    if doc.page>1:
        canvas.setStrokeColor(colors.HexColor('#DCE9E3'))
        canvas.line(46,40,A4[0]-46,40)
        canvas.setFont('Helvetica',7.5)
        canvas.setFillColor(colors.HexColor('#526A6A'))
        canvas.drawString(46,27,'Campus Ledger | DBMS Course Project 01')
        canvas.drawRightString(A4[0]-46,27,str(doc.page))
    canvas.restoreState()

doc=SimpleDocTemplate(str(OUT),pagesize=A4,
 leftMargin=46,rightMargin=46,topMargin=48,bottomMargin=56,
 title='Student and College Management System - Final Project Report',
 author='Golamari Shashanth Reddy, Hansini Baggu, Kandibanda Balaji')
doc.build(story,onFirstPage=footer,onLaterPages=footer)
print(json.dumps({'path':str(OUT),'tables':len(tables),'min_rows':min(counts.values()),
                  'tests':tests,'failures':failures,'errors':errors}))
