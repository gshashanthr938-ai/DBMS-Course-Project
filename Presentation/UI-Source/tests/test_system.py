import os
import sys
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from datetime import date
import json
import pytest
import pymysql

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
os.environ['COLLEGE_CONFIG']=str(ROOT/'.local/test-config.json')
from setup import bootstrap
bootstrap(test=True)
import db
from app import app,attempts
app.config['TESTING']=True

@pytest.fixture
def client():
    attempts.clear()
    return app.test_client()

def signin(client,username='admin'):
    client.get('/login')
    with client.session_transaction() as s: token=s['csrf']
    response=client.post('/login',data={'csrf':token,'username':username,'password':'CollegeDemo!2026'})
    assert response.status_code==302
    return client

def post(client,url,data):
    with client.session_transaction() as s: data={'csrf':s['csrf'],**data}
    return client.post(url,data=data)

def owner(sql,args=()):
    cfg=json.loads((ROOT/'.local/admin.json').read_text())
    con=pymysql.connect(host=cfg['host'],port=cfg['port'],user='root',password=cfg['password'],database='college_test',autocommit=True,cursorclass=pymysql.cursors.DictCursor)
    try:
        with con.cursor() as cur:
            cur.execute(sql,args)
            return cur.fetchall() if cur.description else cur.lastrowid
    finally: con.close()

@pytest.mark.parametrize('path',['/','/students','/students/1','/students/new','/students/1/edit','/registrations','/attendance','/examinations','/fees','/receipts/1','/reports','/users','/audit','/catalog/departments','/catalog/programmes','/catalog/courses','/catalog/faculty','/catalog/semesters','/catalog/curriculum','/catalog/guardians','/catalog/offerings'])
def test_admin_pages_render(client,path):
    signin(client)
    response=client.get(path)
    assert response.status_code==200, response.data[:1000]

@pytest.mark.parametrize('username,allowed,denied',[
 ('faculty','/attendance','/fees'),('exams','/examinations','/users'),
 ('accounts','/fees','/attendance'),('student','/students/1','/students/2'),
 ('student2','/students/2','/students/1'),('hod','/students/1','/students/10')])
def test_role_boundaries(client,username,allowed,denied):
    signin(client,username)
    assert client.get(allowed).status_code==200
    assert client.get(denied).status_code==403

def test_faculty_section_isolation(client):
    signin(client,'faculty')
    assert client.get('/attendance?offering=3').status_code==403
    assert client.get('/examinations?offering=3').status_code==403
    assert post(client,'/attendance',{'offering_id':3,'action':'session','session_date':date.today(),'session_no':5}).status_code==403

def test_student_reports_and_receipts_isolation(client):
    signin(client,'student')
    for kind in ['history','attendance','fees']:
        response=client.get('/reports?kind='+kind+'&format=csv')
        assert response.status_code==200
        assert b'Diya Patel' not in response.data
    assert client.get('/receipts/2').status_code==403
    assert client.get('/reports?kind=results').status_code==403

def test_csrf_and_unauthenticated(client):
    assert client.get('/students').status_code==302
    signin(client)
    assert client.post('/catalog/departments',data={'department_code':'CSRF','department_name':'Bad'}).status_code==400
    assert not db.query("SELECT 1 FROM department WHERE department_code='CSRF'")

def test_login_sql_injection(client):
    client.get('/login')
    response=post(client,'/login',{'username':"admin' OR 1=1 --",'password':'anything'})
    assert response.status_code==200
    with client.session_transaction() as s: assert 'user_id' not in s

def test_admission_update_delete_and_xss(client):
    signin(client)
    values={'programme_id':1,'registration_no':'TEST-CRUD','full_name':'<script>alert(1)</script>','date_of_birth':'2006-04-10','email':'test@example.test','phone':'9000090001','admission_date':str(date.today()),'student_status':'ACTIVE'}
    response=post(client,'/students/new',values); assert response.status_code==302
    sid=db.query("SELECT student_id FROM student WHERE registration_no='TEST-CRUD'",one=True)['student_id']
    page=client.get(f'/students/{sid}'); assert b'&lt;script&gt;' in page.data and b'<script>alert' not in page.data
    values['full_name']='Updated Student'
    assert post(client,f'/students/{sid}/edit',values).status_code==302
    assert db.query('SELECT full_name FROM student WHERE student_id=%s',(sid,),one=True)['full_name']=='Updated Student'
    assert post(client,f'/students/{sid}',{'action':'delete'}).status_code==302
    assert not db.query('SELECT 1 FROM student WHERE student_id=%s',(sid,))

def test_registration_duplicate_across_sections_and_eligibility():
    start=db.query('SELECT start_date FROM semester WHERE semester_id=1',one=True)['start_date']
    for off in [1,2,5]:
        with pytest.raises(pymysql.MySQLError): db.call('register_student',(1,off,start))

def test_concurrent_last_seat():
    start=db.query('SELECT start_date FROM semester WHERE semester_id=1',one=True)['start_date']
    owner('UPDATE course_offering SET capacity=1 WHERE offering_id=2')
    def enroll(sid):
        try: db.call('register_student',(sid,2,start)); return True
        except pymysql.MySQLError: return False
    try:
        with ThreadPoolExecutor(max_workers=2) as pool: results=list(pool.map(enroll,[10,11]))
        assert sorted(results)==[False,True]
        assert db.query('SELECT COUNT(*) n FROM registration WHERE offering_id=2',one=True)['n']==1
    finally:
        owner('DELETE FROM registration WHERE offering_id=2'); owner('UPDATE course_offering SET capacity=2 WHERE offering_id=2')

def test_drop_releases_capacity():
    start=db.query('SELECT start_date FROM semester WHERE semester_id=1',one=True)['start_date']
    db.call('register_student',(12,2,start))
    rid=db.query('SELECT registration_id FROM registration WHERE student_id=12 AND offering_id=2',one=True)['registration_id']
    try:
        db.call('drop_registration',(rid,date.today()))
        assert db.query('SELECT registration_status FROM registration WHERE registration_id=%s',(rid,),one=True)['registration_status']=='DROPPED'
        with pytest.raises(pymysql.MySQLError): db.call('register_student',(12,2,start))
    finally: owner('DELETE FROM registration WHERE registration_id=%s',(rid,))

def test_payment_limits_and_duplicate_receipt():
    for value in [-1,0,12000.01]:
        with pytest.raises(pymysql.MySQLError): db.call('collect_payment',(2,'TEST-INVALID',date.today(),value,'CASH',None))
    db.call('collect_payment',(2,'TEST-RECEIPT',date.today(),100,'CASH',None))
    try:
        with pytest.raises(pymysql.MySQLError): db.call('collect_payment',(2,'TEST-RECEIPT',date.today(),100,'CASH',None))
        assert db.query("SELECT COUNT(*) n FROM payment WHERE receipt_no='TEST-RECEIPT'",one=True)['n']==1
    finally: owner("DELETE FROM payment WHERE receipt_no='TEST-RECEIPT'")

def test_concurrent_payment_limit():
    def pay(number):
        try: db.call('collect_payment',(2,f'TEST-RACE-{number}',date.today(),7000,'CASH',None)); return True
        except pymysql.MySQLError: return False
    try:
        with ThreadPoolExecutor(max_workers=2) as pool: results=list(pool.map(pay,[1,2]))
        assert sorted(results)==[False,True]
        assert db.query('SELECT balance FROM v_fee_balance WHERE bill_id=2',one=True)['balance']==5000
    finally: owner("DELETE FROM payment WHERE receipt_no LIKE %s",('TEST-RACE-%',))

def test_database_account_cannot_bypass_procedures():
    for sql in ["INSERT INTO registration(student_id,offering_id,registered_on) VALUES(10,2,CURRENT_DATE)","INSERT INTO payment(bill_id,receipt_no,paid_on,amount,payment_mode) VALUES(2,'BYPASS',CURRENT_DATE,1,'CASH')"]:
        with pytest.raises(pymysql.MySQLError) as error: db.execute(sql)
        assert error.value.args[0]==1142

def test_attendance_cross_offering_and_range():
    with pytest.raises(pymysql.MySQLError): db.execute("INSERT INTO attendance VALUES(1,5,'PRESENT')")
    with pytest.raises(pymysql.MySQLError): db.execute("UPDATE attendance SET attendance_status='LATE' WHERE registration_id=1 AND session_id=1")
    incomplete=db.query('SELECT attendance_percent,unmarked_count FROM v_attendance_summary WHERE registration_id=9',one=True)
    assert incomplete['attendance_percent'] is None and incomplete['unmarked_count']==1

def test_marks_validation_and_result_pairing():
    with pytest.raises(pymysql.MySQLError): db.execute('UPDATE exam_result SET marks_obtained=51 WHERE registration_id=1 AND exam_id=1')
    with pytest.raises(pymysql.MySQLError): db.execute("INSERT INTO exam_result VALUES(1,3,'SCORED',20)")
    with pytest.raises(pymysql.MySQLError): db.execute("UPDATE exam_result SET result_status='ABSENT' WHERE registration_id=1 AND exam_id=1")

def test_grade_publish_incomplete_rollback_and_final_lock(client):
    signin(client)
    assert post(client,'/examinations',{'action':'publish','offering_id':1}).status_code==400
    assert not db.query('SELECT g.* FROM grade g JOIN registration r ON r.registration_id=g.registration_id WHERE r.offering_id=1')
    try:
        response=post(client,'/examinations',{'action':'publish','offering_id':3})
        assert response.status_code==302,response.data[:500]
        assert len(db.query('SELECT * FROM grade'))==9
        assert db.query('SELECT letter_grade FROM grade WHERE registration_id=10',one=True)['letter_grade']=='B'
        with pytest.raises(pymysql.MySQLError): db.execute('UPDATE exam_result SET marks_obtained=20 WHERE registration_id=10 AND exam_id=3')
        assert post(client,'/examinations',{'action':'reopen','offering_id':3}).status_code==302
        assert not db.query('SELECT * FROM grade')
    finally: owner('DELETE FROM grade')

def test_foreign_keys_unique_codes_and_capacity():
    with pytest.raises(pymysql.MySQLError): db.execute('DELETE FROM department WHERE department_id=1')
    with pytest.raises(pymysql.MySQLError): db.execute("INSERT INTO department(department_code,department_name) VALUES('CSE','Duplicate')")
    with pytest.raises(pymysql.MySQLError): db.execute('UPDATE course_offering SET capacity=1 WHERE offering_id=1')

def test_report_exports(client):
    signin(client)
    for name in ['history','registrations','attendance','results','fees','departments']:
        result=client.get('/reports?kind='+name+'&format=csv')
        assert result.status_code==200 and result.mimetype=='text/csv'
        assert 'attachment' in result.headers['Content-Disposition']

def test_bill_and_payment_ui(client):
    signin(client,'accounts')
    bill={'action':'bill','student_id':1,'semester_id':1,'bill_no':'TEST-UI-BILL','description':'Test laboratory fee','issued_on':str(date.today()),'due_date':str(date.today()),'total_amount':'1250.50'}
    assert post(client,'/fees',bill).status_code==302
    bid=db.query("SELECT bill_id FROM fee_bill WHERE bill_no='TEST-UI-BILL'",one=True)['bill_id']
    try:
        data={'action':'payment','bill_id':bid,'receipt_no':'TEST-UI-PAY','paid_on':str(date.today()),'amount':'250.50','payment_mode':'UPI','transaction_reference':'TEST-UPI-1'}
        assert post(client,'/fees',data).status_code==302
        assert db.query('SELECT balance FROM v_fee_balance WHERE bill_id=%s',(bid,),one=True)['balance']==1000
    finally:
        owner('DELETE FROM payment WHERE bill_id=%s',(bid,)); owner('DELETE FROM fee_bill WHERE bill_id=%s',(bid,))

def test_guardian_link_and_admin_account_creation(client):
    signin(client)
    assert post(client,'/students/1',{'action':'link','guardian_id':2,'relationship_type':'Emergency contact'}).status_code==302
    assert post(client,'/students/1',{'action':'unlink','guardian_id':2}).status_code==302
    assert post(client,'/users',{'username':'test-exams','password':'StrongTest!2026','role':'EXAMS'}).status_code==302
    row=db.query("SELECT password_hash FROM app_user WHERE username='test-exams'",one=True)
    assert row and row['password_hash']!='StrongTest!2026'
