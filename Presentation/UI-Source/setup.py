"""Create a dedicated MySQL database and seed it. Never resets the main database."""
import argparse
import json
import secrets
from datetime import date, timedelta
from pathlib import Path
import pymysql
from werkzeug.security import generate_password_hash

ROOT = Path(__file__).resolve().parent
LOCAL = ROOT / '.local'

def sql_statements(text):
    delimiter = ';'
    buffer = ''
    for line in text.splitlines():
        if line.strip().upper().startswith('DELIMITER '):
            delimiter = line.strip().split()[1]
            continue
        if line.lstrip().startswith('--') or not line.strip(): continue
        buffer += line + '\n'
        if buffer.rstrip().endswith(delimiter):
            yield buffer.rstrip()[:-len(delimiter)]
            buffer = ''
    if buffer.strip(): raise ValueError('Unterminated SQL statement')

def bootstrap(test=False):
    LOCAL.mkdir(exist_ok=True)
    admin_path = LOCAL / 'admin.json'
    admin = json.loads(admin_path.read_text()) if admin_path.exists() else {'host':'127.0.0.1','port':3308,'password':''}
    con = pymysql.connect(host=admin['host'],port=admin['port'],user='root',password=admin['password'],autocommit=True,charset='utf8mb4')
    name = 'college_test' if test else 'college_management'
    user = 'college_test_app' if test else 'college_app'
    path = LOCAL / ('test-config.json' if test else 'config.json')
    with con.cursor() as cur:
        cur.execute('SELECT @@datadir')
        if Path(cur.fetchone()[0]).resolve() != (LOCAL/'mysql-data').resolve():
            raise RuntimeError('Setup only manages its dedicated .local/mysql-data server.')
        cur.execute('SHOW DATABASES LIKE %s',(name,))
        exists = cur.fetchone()
        if exists and not test:
            raise RuntimeError('Main database already exists. Setup refuses to overwrite it. Use start.ps1.')
        if exists:
            cur.execute('DROP DATABASE college_test')
        cur.execute(f'CREATE DATABASE `{name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci')
        cur.execute(f'USE `{name}`')
        for filename in ['01_schema.sql','02_routines.sql','03_views_reports.sql']:
            for statement in sql_statements((ROOT/'sql'/filename).read_text(encoding='utf-8')):
                cur.execute(statement)
        seed(cur, name, test)
        password = secrets.token_urlsafe(32)
        cur.execute(f"CREATE USER IF NOT EXISTS '{user}'@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY %s",(password,))
        cur.execute(f"ALTER USER '{user}'@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY %s",(password,))
        cur.execute(f"REVOKE ALL PRIVILEGES, GRANT OPTION FROM '{user}'@'127.0.0.1'")
        cur.execute(f"GRANT SELECT ON `{name}`.* TO '{user}'@'127.0.0.1'")
        for table in ['department','programme','course','faculty','semester','student','guardian','student_guardian','programme_course','course_offering','class_session','attendance','examination','exam_result']:
            cur.execute(f"GRANT INSERT,UPDATE,DELETE ON `{name}`.`{table}` TO '{user}'@'127.0.0.1'")
        for table in ['fee_bill','grade']:
            cur.execute(f"GRANT INSERT,DELETE ON `{name}`.`{table}` TO '{user}'@'127.0.0.1'")
        cur.execute(f"GRANT INSERT ON `{name}`.audit_event TO '{user}'@'127.0.0.1'")
        cur.execute(f"GRANT INSERT ON `{name}`.app_user TO '{user}'@'127.0.0.1'")
        for proc in ['register_student','drop_registration','collect_payment']:
            cur.execute(f"GRANT EXECUTE ON PROCEDURE `{name}`.{proc} TO '{user}'@'127.0.0.1'")
        if not admin['password']:
            admin['password']=secrets.token_urlsafe(32)
            cur.execute("ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY %s",(admin['password'],))
            admin_path.write_text(json.dumps(admin,indent=2))
    con.close()
    cfg={'host':admin['host'],'port':admin['port'],'database':name,'user':user,'password':password,'secret_key':secrets.token_hex(32),'attendance_threshold':75}
    path.write_text(json.dumps(cfg,indent=2))
    print(f'Created {name}. Configuration saved locally. Demo sign-ins are in DEMO_ACCOUNTS.md.')

def seed(cur, database, test):
    statements=[]
    def ins(table, cols, rows):
        sql=f"INSERT INTO {table} ({','.join(cols.split())}) VALUES ({','.join(['%s']*len(cols.split()))})"
        for row in rows:
            statements.append(cur.mogrify(sql,row)+';')
            cur.execute(sql,row)
    ins('department','department_code department_name',[('CSE','Computer Science and Engineering'),('ECE','Electronics and Communication')])
    ins('programme','department_id programme_code programme_name duration_terms',[(1,'BTECH-CSE','BTech Computer Science',8),(2,'BTECH-ECE','BTech Electronics',8)])
    ins('course','department_id course_code course_title credits',[(1,'CS301','Database Management Systems',4),(1,'CS302','Operating Systems',4),(1,'CS303','Data Structures',4),(2,'EC301','Digital Electronics',3)])
    ins('faculty','department_id employee_no full_name email phone',[(1,'FAC001','Dr Meera Rao','meera@example.test','9000000101'),(1,'FAC002','Arjun Nair','arjun@example.test','9000000102'),(2,'FAC003','Dr Kavya Iyer','kavya@example.test','9000000103')])
    today=date.today(); start=today-timedelta(days=70); end=today+timedelta(days=90)
    ins('semester','academic_year term_name start_date end_date',[(f'{today.year}-{str(today.year+1)[2:]}','Odd',start,end)])
    names=['Aarav Sharma','Diya Patel','Ishaan Verma','Ananya Singh','Rohan Gupta','Kavya Reddy','Aditya Rao','Meera Joshi','Vihaan Shah','Sara Khan','Arjun Das','Tara Nair']
    ins('student','programme_id registration_no full_name date_of_birth email phone admission_date student_status',[(1 if i<9 else 2,f'2026{"CS" if i<9 else "EC"}{i+1:03}',n,date(2006,1+i%12,10),f'student{i+1}@example.test',f'900001{i+1:04}',start-timedelta(days=300),'ACTIVE') for i,n in enumerate(names)])
    ins('guardian','full_name phone email',[(f'Guardian {i}',f'900002{i:04}',f'guardian{i}@example.test') for i in range(1,12)])
    ins('student_guardian','student_id guardian_id relationship_type',[(i,min(i,11),'Parent') for i in range(1,13)])
    ins('programme_course','programme_id course_id recommended_term course_type',[(1,1,3,'CORE'),(1,2,3,'CORE'),(1,3,3,'CORE'),(2,4,3,'CORE'),(2,1,3,'ELECTIVE')])
    ins('course_offering','course_id semester_id faculty_id section_code capacity',[(1,1,1,'A',12),(1,1,1,'B',2),(2,1,2,'A',12),(3,1,2,'A',12),(4,1,3,'A',6)])
    registrations=[(i,1,start) for i in range(1,10)]+[(i,3,start) for i in range(1,10)]+[(i,5,start) for i in range(10,13)]
    ins('registration','student_id offering_id registered_on',registrations)
    sessions=[(off,start+timedelta(days=day),1,topic) for off in [1,3,5] for day,topic in [(7,'Introduction'),(14,'Core concepts'),(21,'Worked examples'),(28,'Practice session')]]
    ins('class_session','offering_id session_date session_no topic',sessions)
    att=[]
    for rid,(sid,off,_) in enumerate(registrations,1):
        for session_id,(so,_,_,_) in enumerate(sessions,1):
            if so==off and not(sid==9 and session_id==4):
                att.append((rid,session_id,'ABSENT' if (sid in [2,5] and session_id%2==0) else 'PRESENT'))
    ins('attendance','registration_id session_id attendance_status',att)
    exams=[(off,ex,start+timedelta(days=days),maximum,weight) for off in [1,3,5] for ex,days,maximum,weight in [('Internal',35,50,40),('Final',49,100,60)]]
    ins('examination','offering_id exam_name exam_date max_marks weight_percent',exams)
    results=[]
    for rid,(sid,off,_) in enumerate(registrations,1):
        for eid,(eo,_,_,maximum,_) in enumerate(exams,1):
            if eo==off and not(sid==9 and eid==2):
                absent=sid==5 and eid==2
                results.append((rid,eid,'ABSENT' if absent else 'SCORED',None if absent else round(maximum*(.5+(sid%5)*.09),2)))
    ins('exam_result','registration_id exam_id result_status marks_obtained',results)
    ins('grade_scale','letter_grade minimum_score grade_points',[('O',90,10),('A+',80,9),('A',70,8),('B+',60,7),('B',50,6),('C',40,5),('F',0,0)])
    ins('fee_bill','student_id semester_id bill_no description issued_on due_date total_amount',[(i,1,f'BILL-{i:03}','Semester tuition',start,start+timedelta(days=45),20000 if i<10 else 18000) for i in range(1,13)])
    ins('payment','bill_id receipt_no paid_on amount payment_mode transaction_reference',[(i,f'RCPT-{i:03}',start+timedelta(days=10),20000 if i in [1,3,7] else 8000,'BANK_TRANSFER',f'DEMO-TXN-{i:03}') for i in range(1,10)])
    password='CollegeDemo!2026'
    users=[('admin','ADMIN',None,None,None),('faculty','FACULTY',None,1,None),('exams','EXAMS',None,None,None),('accounts','ACCOUNTS',None,None,None),('student','STUDENT',1,None,None),('student2','STUDENT',2,None,None),('hod','HOD',None,None,1)]
    ins('app_user','username password_hash role student_id faculty_id department_id',[(u,generate_password_hash(password),r,s,f,d) for u,r,s,f,d in users])
    if not test:
        (ROOT/'sql'/'04_sample_data.sql').write_text('-- Synthetic demonstration records. All contacts use example.test.\n-- Import into an EMPTY schema after 01-03. Dates reflect the setup date.\n'+'\n'.join(statements)+'\n',encoding='utf-8')
        (ROOT/'DEMO_ACCOUNTS.md').write_text('# Local demonstration accounts\n\nAll accounts use password `CollegeDemo!2026`. These are local demo accounts, not production credentials.\n\n| Username | Role |\n|---|---|\n'+'\n'.join(f'| {u} | {r} |' for u,r,_,_,_ in users)+'\n\nFaculty is assigned to DBMS sections. Student and student2 are different students for access-isolation tests. HOD belongs to CSE.\n')

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--test',action='store_true',help='Recreate only the dedicated college_test database')
    bootstrap(parser.parse_args().test)
