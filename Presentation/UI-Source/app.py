import csv
import io
import secrets
import threading
import time
from datetime import date, timedelta
from decimal import Decimal, InvalidOperation
from functools import wraps
from flask import Flask, abort, flash, g, redirect, render_template, request, session, url_for, Response
from werkzeug.security import check_password_hash, generate_password_hash
import pymysql
import db
from catalog import CATALOG, OPTION_SQL

app=Flask(__name__)
cfg=db.settings()
app.config.update(SECRET_KEY=cfg['secret_key'],SESSION_COOKIE_HTTPONLY=True,
 SESSION_COOKIE_SAMESITE='Lax',PERMANENT_SESSION_LIFETIME=timedelta(hours=4),MAX_CONTENT_LENGTH=1024*1024)
attempts={}; attempts_lock=threading.Lock()

def roles(*allowed):
    def decorate(fn):
        @wraps(fn)
        def wrapped(*args,**kwargs):
            if not g.user: return redirect(url_for('login'))
            if g.user['role'] not in allowed: abort(403)
            return fn(*args,**kwargs)
        return wrapped
    return decorate

@app.before_request
def prepare():
    g.user=db.query('SELECT user_id,username,role,student_id,faculty_id,department_id FROM app_user WHERE user_id=%s',(session.get('user_id'),),one=True) if session.get('user_id') else None
    session.setdefault('csrf',secrets.token_urlsafe(32))
    if request.method=='POST' and not secrets.compare_digest(session['csrf'],request.form.get('csrf','')): abort(400,'Your form expired. Refresh the page and try again.')

@app.after_request
def security(response):
    response.headers['X-Content-Type-Options']='nosniff'
    response.headers['X-Frame-Options']='DENY'
    response.headers['Referrer-Policy']='same-origin'
    response.headers['Content-Security-Policy']="default-src 'self'; style-src 'self'; script-src 'self'; img-src 'self' data:; frame-ancestors 'none'; form-action 'self'"
    if g.get('user'): response.headers['Cache-Control']='no-store'
    return response

@app.context_processor
def shared():
    return {'user':g.get('user'),'csrf':session.get('csrf'),'today':date.today().isoformat(),'catalog':CATALOG}

@app.template_filter('money')
def money(value): return f'{Decimal(value or 0):,.2f}'

@app.template_filter('label')
def label(value): return str(value).replace('_',' ').title()

def integer(name,form=None):
    try: return int((form or request.form)[name])
    except (ValueError,KeyError): abort(400,f'{name.replace("_"," ")} must be a whole number.')

def amount(name,form=None):
    try:
        v=Decimal((form or request.form)[name])
        if not v.is_finite() or v.as_tuple().exponent < -2: raise ValueError()
        return v
    except (InvalidOperation,ValueError,KeyError): abort(400,'Enter a valid amount with at most two decimal places.')

def text(name,required=True):
    v=request.form.get(name,'').strip()
    if required and not v: abort(400,f'{name.replace("_"," ")} is required.')
    return v or None

def day(name):
    try: return date.fromisoformat(request.form.get(name,''))
    except ValueError: abort(400,'Enter a valid date.')

def audit(action,detail,con=None):
    db.execute('INSERT INTO audit_event(user_id,action,detail) VALUES(%s,%s,%s)',(g.user['user_id'],action,str(detail)[:255]),con)

def options(name):
    if name=='course_types': return [{'id':x,'label':x} for x in ['CORE','ELECTIVE']]
    return db.query(OPTION_SQL[name])

def offering_rows():
    sql='SELECT o.*,CONCAT(c.course_code," · ",c.course_title," / ",o.section_code," / ",s.academic_year," ",s.term_name) label FROM course_offering o JOIN course c ON c.course_id=o.course_id JOIN semester s ON s.semester_id=o.semester_id'
    args=()
    if g.user['role']=='FACULTY': sql+=' WHERE o.faculty_id=%s'; args=(g.user['faculty_id'],)
    return db.query(sql+' ORDER BY c.course_code,o.section_code',args)

def check_offering(offering_id,con=None):
    row=db.query('SELECT * FROM course_offering WHERE offering_id=%s',(offering_id,),one=True,con=con)
    if not row: abort(404)
    if g.user['role']=='FACULTY' and row['faculty_id']!=g.user['faculty_id']: abort(403)
    return row

def can_student(student_id):
    if g.user['role']=='STUDENT' and g.user['student_id']!=student_id: abort(403)
    if g.user['role']=='HOD' and not db.query('SELECT 1 FROM student s JOIN programme p ON p.programme_id=s.programme_id WHERE s.student_id=%s AND p.department_id=%s',(student_id,g.user['department_id']),one=True): abort(403)

@app.route('/login',methods=['GET','POST'])
def login():
    if request.method=='POST':
        key=request.remote_addr
        with attempts_lock:
            record=attempts.get(key,[]); record=[t for t in record if time.time()-t<300]
            if len(record)>=10: abort(429,'Too many sign-in attempts. Wait five minutes.')
            attempts[key]=record+[time.time()]
        row=db.query('SELECT * FROM app_user WHERE username=%s',(request.form.get('username','').strip(),),one=True)
        if row and check_password_hash(row['password_hash'],request.form.get('password','')):
            with attempts_lock: attempts.pop(key,None)
            session.clear(); session['user_id']=row['user_id']; session['csrf']=secrets.token_urlsafe(32); session.permanent=True
            return redirect(url_for('dashboard'))
        flash('Username or password is incorrect.','error')
    return render_template('login.html',title='Sign in')

@app.post('/logout')
def logout(): session.clear(); return redirect(url_for('login'))

@app.get('/')
@roles('ADMIN','FACULTY','EXAMS','ACCOUNTS','STUDENT','HOD')
def dashboard():
    if g.user['role']=='STUDENT': return redirect(url_for('student_detail',student_id=g.user['student_id']))
    if g.user['role']=='FACULTY': return redirect(url_for('attendance_page'))
    if g.user['role']=='ACCOUNTS': return redirect(url_for('fees'))
    department=g.user['department_id'] if g.user['role']=='HOD' else None
    where=' WHERE p.department_id=%s' if department else ''; args=(department,) if department else ()
    count=db.query('SELECT COUNT(*) n FROM student s JOIN programme p ON p.programme_id=s.programme_id'+where,args,one=True)['n']
    offerings=db.query('SELECT COUNT(*) n FROM course_offering o JOIN course c ON c.course_id=o.course_id'+(' WHERE c.department_id=%s' if department else ''),args,one=True)['n']
    shortage=db.query('SELECT COUNT(*) n FROM v_attendance_summary WHERE attendance_percent<%s'+(' AND department_id=%s' if department else ''),(cfg['attendance_threshold'],)+args,one=True)['n']
    pending=db.query('SELECT COALESCE(SUM(pending_results),0) n FROM v_result_analysis'+(' WHERE department_id=%s' if department else ''),args,one=True)['n']
    recent=db.query('SELECT s.student_id,s.registration_no,s.full_name,p.programme_name FROM student s JOIN programme p ON p.programme_id=s.programme_id'+where+' ORDER BY s.student_id DESC LIMIT 6',args)
    return render_template('dashboard.html',title='Overview',stats=[('Students',count),('Course sections',offerings),('Attendance alerts',shortage),('Results pending',pending)],recent=recent)

@app.route('/catalog/<entity>',methods=['GET','POST'])
@roles('ADMIN')
def catalog_page(entity):
    if entity not in CATALOG: abort(404)
    title,table,keys,fields=CATALOG[entity]
    row=None
    if request.args.get('edit'):
        values=request.args['edit'].split(',')
        if len(values)!=len(keys) or not all(v.isdigit() for v in values): abort(400)
        row=db.query(f'SELECT * FROM {table} WHERE '+ ' AND '.join(k+'=%s' for k in keys),values,one=True)
        if not row: abort(404)
    if request.method=='POST':
        action=request.form.get('action','create')
        with db.transaction() as con:
            if action in ['update','delete']:
                ids=request.form.get('record_key','').split(',')
                if len(ids)!=len(keys) or not all(v.isdigit() for v in ids): abort(400)
                predicate=' AND '.join(k+'=%s' for k in keys)
                if action=='delete': db.execute(f'DELETE FROM {table} WHERE {predicate}',ids,con)
                else:
                    cols=[f[0] for f in fields if f[0] not in keys]
                    vals=[text(c,c not in ['email','phone']) for c in cols]
                    db.execute(f'UPDATE {table} SET '+','.join(c+'=%s' for c in cols)+f' WHERE {predicate}',vals+ids,con)
            elif action=='create':
                cols=[f[0] for f in fields]; vals=[text(c,c not in ['email','phone']) for c in cols]
                db.execute(f'INSERT INTO {table} ({",".join(cols)}) VALUES ({",".join(["%s"]*len(cols))})',vals,con)
            else: abort(400)
            audit(f'{action} {table}',request.form.get('record_key','new record'),con)
        flash(f'{title} saved.','success'); return redirect(url_for('catalog_page',entity=entity))
    rows=db.query(f'SELECT * FROM {table} ORDER BY {keys[0]} DESC LIMIT 500')
    choices={f[3]:options(f[3]) for f in fields if f[2]=='select'}
    return render_template('catalog.html',title=title,entity=entity,fields=fields,rows=rows,keys=keys,choices=choices,edit=row)

@app.get('/students')
@roles('ADMIN','EXAMS','ACCOUNTS','HOD')
def students():
    search=request.args.get('q','').strip()
    sql='SELECT s.*,p.programme_name FROM student s JOIN programme p ON p.programme_id=s.programme_id WHERE (s.full_name LIKE %s OR s.registration_no LIKE %s)'
    args=[f'%{search}%',f'%{search}%']
    if g.user['role']=='HOD': sql+=' AND p.department_id=%s'; args.append(g.user['department_id'])
    return render_template('students.html',title='Students',rows=db.query(sql+' ORDER BY s.registration_no LIMIT 500',args),search=search)

@app.route('/students/new',methods=['GET','POST'])
@app.route('/students/<int:student_id>/edit',methods=['GET','POST'])
@roles('ADMIN')
def student_form(student_id=None):
    row=db.query('SELECT * FROM student WHERE student_id=%s',(student_id,),one=True) if student_id else None
    if student_id and not row: abort(404)
    if request.method=='POST':
        cols=['programme_id','registration_no','full_name','date_of_birth','email','phone','admission_date','student_status']
        values=[integer('programme_id'),text('registration_no'),text('full_name'),day('date_of_birth'),text('email',False),text('phone',False),day('admission_date'),text('student_status')]
        if values[6]>date.today(): abort(400,'Admission date cannot be in the future.')
        with db.transaction() as con:
            if student_id: db.execute('UPDATE student SET '+','.join(c+'=%s' for c in cols)+' WHERE student_id=%s',values+[student_id],con)
            else: student_id=db.execute('INSERT INTO student ('+','.join(cols)+') VALUES ('+','.join(['%s']*len(cols))+')',values,con)
            audit('save student',student_id,con)
        flash('Student record saved.','success'); return redirect(url_for('student_detail',student_id=student_id))
    return render_template('student_form.html',title='Edit student' if row else 'New admission',edit=row,programmes=options('programmes'))

@app.route('/students/<int:student_id>',methods=['GET','POST'])
@roles('ADMIN','EXAMS','ACCOUNTS','STUDENT','HOD')
def student_detail(student_id):
    can_student(student_id)
    row=db.query('SELECT s.*,p.programme_name FROM student s JOIN programme p ON p.programme_id=s.programme_id WHERE student_id=%s',(student_id,),one=True)
    if not row: abort(404)
    if request.method=='POST':
        if g.user['role']!='ADMIN': abort(403)
        action=request.form.get('action')
        with db.transaction() as con:
            if action=='link': db.execute('INSERT INTO student_guardian VALUES(%s,%s,%s)',(student_id,integer('guardian_id'),text('relationship_type')),con)
            elif action=='unlink': db.execute('DELETE FROM student_guardian WHERE student_id=%s AND guardian_id=%s',(student_id,integer('guardian_id')),con)
            elif action=='delete': db.execute('DELETE FROM student WHERE student_id=%s',(student_id,),con)
            else: abort(400)
            audit(action+' student',student_id,con)
        flash('Student record updated.','success')
        return redirect(url_for('students') if action=='delete' else url_for('student_detail',student_id=student_id))
    guardians=db.query('SELECT g.*,sg.relationship_type FROM guardian g JOIN student_guardian sg ON sg.guardian_id=g.guardian_id WHERE sg.student_id=%s',(student_id,))
    history=db.query('SELECT * FROM v_academic_history WHERE student_id=%s',(student_id,)) if g.user['role']!='ACCOUNTS' else []
    attendance=db.query('SELECT * FROM v_attendance_summary WHERE student_id=%s',(student_id,)) if g.user['role']!='ACCOUNTS' else []
    bills=db.query('SELECT * FROM v_fee_balance WHERE student_id=%s',(student_id,)) if g.user['role'] in ['ADMIN','ACCOUNTS','STUDENT'] else []
    results=db.query('SELECT c.course_code,e.exam_name,e.max_marks,er.result_status,er.marks_obtained FROM exam_result er JOIN registration r ON r.registration_id=er.registration_id JOIN examination e ON e.exam_id=er.exam_id JOIN course_offering o ON o.offering_id=e.offering_id JOIN course c ON c.course_id=o.course_id WHERE r.student_id=%s',(student_id,)) if g.user['role']!='ACCOUNTS' else []
    return render_template('student_detail.html',title=row['full_name'],student=row,guardians=guardians,guardian_options=options('guardians') if g.user['role']=='ADMIN' else [],history=history,attendance=attendance,bills=bills,results=results)

@app.route('/registrations',methods=['GET','POST'])
@roles('ADMIN')
def registrations():
    if request.method=='POST':
        if request.form.get('action')=='drop':
            db.call('drop_registration',(integer('registration_id'),day('dropped_on'))); audit('drop registration',request.form['registration_id'])
        else:
            db.call('register_student',(integer('student_id'),integer('offering_id'),day('registered_on'))); audit('register student',request.form['student_id'])
        flash('Registration saved.','success'); return redirect(url_for('registrations'))
    return render_template('registrations.html',title='Course registrations',students=db.query("SELECT student_id,registration_no,full_name FROM student WHERE student_status='ACTIVE' ORDER BY full_name"),offerings=offering_rows(),rows=db.query('SELECT * FROM v_academic_history ORDER BY registration_id DESC LIMIT 300'))

@app.route('/attendance',methods=['GET','POST'])
@roles('ADMIN','FACULTY')
def attendance_page():
    offerings=offering_rows()
    offering_id=request.args.get('offering',type=int) or (offerings[0]['offering_id'] if offerings else None)
    if offering_id: check_offering(offering_id)
    if request.method=='POST':
        offering_id=integer('offering_id'); check_offering(offering_id)
        with db.transaction() as con:
            # Serialize roster changes with enrollment and grade workflows.
            db.query('SELECT offering_id FROM course_offering WHERE offering_id=%s FOR UPDATE',(offering_id,),one=True,con=con)
            if request.form.get('action')=='session':
                session_id=db.execute('INSERT INTO class_session(offering_id,session_date,session_no,topic) VALUES(%s,%s,%s,%s)',(offering_id,day('session_date'),integer('session_no'),text('topic',False)),con)
            else:
                session_id=integer('session_id')
                held=db.query('SELECT * FROM class_session WHERE session_id=%s AND offering_id=%s',(session_id,offering_id),one=True,con=con)
                if not held: abort(404)
                roster=db.query('SELECT registration_id FROM registration WHERE offering_id=%s AND registered_on<=%s AND (dropped_on IS NULL OR dropped_on>%s)',(offering_id,held['session_date'],held['session_date']),con=con)
                for row in roster:
                    status=request.form.get(f'status_{row["registration_id"]}','')
                    if status not in ['PRESENT','ABSENT','']: abort(400)
                    if status: db.execute('INSERT INTO attendance VALUES(%s,%s,%s) ON DUPLICATE KEY UPDATE attendance_status=VALUES(attendance_status)',(row['registration_id'],session_id,status),con)
                    else: db.execute('DELETE FROM attendance WHERE registration_id=%s AND session_id=%s',(row['registration_id'],session_id),con)
            audit('save attendance',f'offering {offering_id}, session {session_id}',con)
        flash('Attendance saved.','success'); return redirect(url_for('attendance_page',offering=offering_id,session_id=session_id))
    sessions=db.query('SELECT * FROM class_session WHERE offering_id=%s ORDER BY session_date DESC,session_no DESC',(offering_id,)) if offering_id else []
    session_id=request.args.get('session_id',type=int) or (sessions[0]['session_id'] if sessions else None)
    held=next((r for r in sessions if r['session_id']==session_id),None)
    if session_id and not held: abort(404)
    roster=db.query('SELECT r.registration_id,s.registration_no,s.full_name,a.attendance_status FROM registration r JOIN student s ON s.student_id=r.student_id LEFT JOIN attendance a ON a.registration_id=r.registration_id AND a.session_id=%s WHERE r.offering_id=%s AND r.registered_on<=%s AND (r.dropped_on IS NULL OR r.dropped_on>%s) ORDER BY s.registration_no',(session_id,offering_id,held['session_date'],held['session_date'])) if held else []
    return render_template('attendance.html',title='Attendance',offerings=offerings,offering_id=offering_id,sessions=sessions,held=held,roster=roster)

@app.route('/examinations',methods=['GET','POST'])
@roles('ADMIN','EXAMS','FACULTY')
def examinations():
    offerings=offering_rows(); offering_id=request.args.get('offering',type=int) or (offerings[0]['offering_id'] if offerings else None)
    if offering_id: check_offering(offering_id)
    if request.method=='POST':
        offering_id=integer('offering_id'); check_offering(offering_id); action=text('action')
        with db.transaction() as con:
            db.query('SELECT offering_id FROM course_offering WHERE offering_id=%s FOR UPDATE',(offering_id,),one=True,con=con)
            if action=='create':
                if g.user['role']=='FACULTY': abort(403)
                db.execute('INSERT INTO examination(offering_id,exam_name,exam_date,max_marks,weight_percent) VALUES(%s,%s,%s,%s,%s)',(offering_id,text('exam_name'),day('exam_date'),amount('max_marks'),amount('weight_percent')),con)
            elif action in ['publish','reopen']:
                if g.user['role']=='FACULTY': abort(403)
                if action=='reopen': db.execute('DELETE g FROM grade g JOIN registration r ON r.registration_id=g.registration_id WHERE r.offering_id=%s',(offering_id,),con)
                else: publish_grades(offering_id,con)
            elif action=='delete_exam':
                if g.user['role']=='FACULTY': abort(403)
                db.execute('DELETE FROM examination WHERE exam_id=%s AND offering_id=%s',(integer('exam_id'),offering_id),con)
            elif action=='results':
                exam=db.query('SELECT * FROM examination WHERE exam_id=%s AND offering_id=%s',(integer('exam_id'),offering_id),one=True,con=con)
                if not exam: abort(404)
                if exam['exam_date']>date.today(): abort(400,'Results cannot be entered before the examination date.')
                roster=db.query("SELECT registration_id FROM registration WHERE offering_id=%s AND registration_status='ACTIVE'",(offering_id,),con=con)
                for row in roster:
                    rid=row['registration_id']; status=request.form.get(f'result_{rid}','')
                    if status not in ['','SCORED','ABSENT']: abort(400)
                    if not status:
                        db.execute('DELETE FROM exam_result WHERE registration_id=%s AND exam_id=%s',(rid,exam['exam_id']),con); continue
                    marks=amount(f'marks_{rid}') if status=='SCORED' else None
                    db.execute('INSERT INTO exam_result VALUES(%s,%s,%s,%s) ON DUPLICATE KEY UPDATE result_status=VALUES(result_status),marks_obtained=VALUES(marks_obtained)',(rid,exam['exam_id'],status,marks),con)
            else: abort(400)
            audit(action+' examinations',offering_id,con)
        flash('Examination records saved.','success'); return redirect(url_for('examinations',offering=offering_id,exam=request.form.get('exam_id')))
    exams=db.query('SELECT * FROM examination WHERE offering_id=%s ORDER BY exam_date',(offering_id,)) if offering_id else []
    exam_id=request.args.get('exam',type=int) or (exams[0]['exam_id'] if exams else None)
    exam=next((r for r in exams if r['exam_id']==exam_id),None)
    if exam_id and not exam: abort(404)
    roster=db.query("SELECT r.registration_id,s.registration_no,s.full_name,er.result_status,er.marks_obtained,g.letter_grade FROM registration r JOIN student s ON s.student_id=r.student_id LEFT JOIN exam_result er ON er.registration_id=r.registration_id AND er.exam_id=%s LEFT JOIN grade g ON g.registration_id=r.registration_id WHERE r.offering_id=%s AND r.registration_status='ACTIVE' ORDER BY s.registration_no",(exam_id,offering_id)) if exam else []
    return render_template('examinations.html',title='Examinations and grades',offerings=offerings,offering_id=offering_id,exams=exams,exam=exam,roster=roster,scale=db.query('SELECT * FROM grade_scale ORDER BY minimum_score DESC'))

def publish_grades(offering_id,con):
    exams=db.query('SELECT * FROM examination WHERE offering_id=%s',(offering_id,),con=con)
    if not exams or sum(e['weight_percent'] for e in exams)!=100: abort(400,'Assessment weights must total exactly 100 before publishing.')
    if any(e['exam_date']>date.today() for e in exams): abort(400,'All examinations must have taken place before publishing.')
    rows=db.query("SELECT r.registration_id,COUNT(er.exam_id) completed,SUM(COALESCE(er.marks_obtained,0)/e.max_marks*e.weight_percent) score FROM registration r JOIN examination e ON e.offering_id=r.offering_id LEFT JOIN exam_result er ON er.registration_id=r.registration_id AND er.exam_id=e.exam_id WHERE r.offering_id=%s AND r.registration_status='ACTIVE' GROUP BY r.registration_id",(offering_id,),con=con)
    if not rows: abort(400,'There are no active registrations.')
    if any(row['completed']!=len(exams) for row in rows): abort(400,'Enter every result or mark the student absent before publishing.')
    if db.query('SELECT 1 FROM grade g JOIN registration r ON r.registration_id=g.registration_id WHERE r.offering_id=%s LIMIT 1',(offering_id,),one=True,con=con): abort(400,'Grades are already published. Reopen before making changes.')
    scale=db.query('SELECT * FROM grade_scale ORDER BY minimum_score DESC',con=con)
    for row in rows:
        letter=next(s['letter_grade'] for s in scale if row['score']>=s['minimum_score'])
        db.execute('INSERT INTO grade VALUES(%s,%s,%s)',(row['registration_id'],letter,date.today()),con)

@app.route('/fees',methods=['GET','POST'])
@roles('ADMIN','ACCOUNTS')
def fees():
    if request.method=='POST':
        if request.form.get('action')=='bill':
            issued=day('issued_on')
            if issued>date.today(): abort(400,'Bill issue date cannot be in the future.')
            with db.transaction() as con:
                bill_id=db.execute('INSERT INTO fee_bill(student_id,semester_id,bill_no,description,issued_on,due_date,total_amount) VALUES(%s,%s,%s,%s,%s,%s,%s)',(integer('student_id'),integer('semester_id'),text('bill_no'),text('description'),issued,day('due_date'),amount('total_amount')),con)
                audit('issue fee bill',bill_id,con)
        else:
            db.call('collect_payment',(integer('bill_id'),text('receipt_no'),day('paid_on'),amount('amount'),text('payment_mode'),text('transaction_reference',False))); audit('collect payment',request.form['receipt_no'])
        flash('Fee record saved.','success'); return redirect(url_for('fees'))
    rows=db.query('SELECT b.*,s.registration_no,s.full_name FROM v_fee_balance b JOIN student s ON s.student_id=b.student_id ORDER BY b.bill_id DESC')
    payments=db.query('SELECT p.*,b.bill_no,s.full_name FROM payment p JOIN fee_bill b ON b.bill_id=p.bill_id JOIN student s ON s.student_id=b.student_id ORDER BY p.payment_id DESC LIMIT 100')
    return render_template('fees.html',title='Fees and payments',rows=rows,payments=payments,students=db.query('SELECT student_id,registration_no,full_name FROM student ORDER BY full_name'),semesters=options('semesters'),billed=sum(r['total_amount'] for r in rows),collected=sum(r['paid_amount'] for r in rows),due=sum(r['balance'] for r in rows))

@app.get('/receipts/<int:payment_id>')
@roles('ADMIN','ACCOUNTS','STUDENT')
def receipt(payment_id):
    row=db.query('SELECT p.*,b.bill_no,b.student_id,b.description,s.registration_no,s.full_name,v.balance FROM payment p JOIN fee_bill b ON b.bill_id=p.bill_id JOIN student s ON s.student_id=b.student_id JOIN v_fee_balance v ON v.bill_id=b.bill_id WHERE p.payment_id=%s',(payment_id,),one=True)
    if not row: abort(404)
    can_student(row['student_id'])
    return render_template('receipt.html',title='Payment receipt',receipt=row)

REPORTS={'history':'Student academic history','registrations':'Course registration list','attendance':'Attendance shortage','results':'Result analysis','fees':'Fee dues','departments':'Department summary'}

@app.get('/reports')
@roles('ADMIN','EXAMS','ACCOUNTS','FACULTY','STUDENT','HOD')
def reports():
    allowed={'ADMIN':list(REPORTS),'EXAMS':['history','registrations','attendance','results','departments'],'ACCOUNTS':['fees'],'FACULTY':['history','registrations','attendance','results'],'STUDENT':['history','attendance','fees'],'HOD':['history','registrations','attendance','results','departments']}[g.user['role']]
    kind=request.args.get('kind',allowed[0])
    if kind not in allowed: abort(403)
    clauses=[]; args=[]
    if kind in ['history','registrations']:
        sql='SELECT * FROM v_academic_history'
        if kind=='registrations': clauses.append("registration_status='ACTIVE'")
    elif kind=='attendance':
        sql='SELECT * FROM v_attendance_summary'; clauses.append('(attendance_percent<%s OR unmarked_count>0 OR held_sessions=0)'); args.append(cfg['attendance_threshold'])
    elif kind=='results': sql='SELECT * FROM v_result_analysis'
    elif kind=='fees': sql='SELECT b.*,s.registration_no,s.full_name FROM v_fee_balance b JOIN student s ON s.student_id=b.student_id'; clauses.append('balance>0')
    else:
        sql='SELECT d.department_id,d.department_name,COUNT(DISTINCT p.programme_id) programmes,COUNT(s.student_id) students FROM department d LEFT JOIN programme p ON p.department_id=d.department_id LEFT JOIN student s ON s.programme_id=p.programme_id'
    if g.user['role']=='STUDENT': clauses.append('b.student_id=%s' if kind=='fees' else 'student_id=%s'); args.append(g.user['student_id'])
    if g.user['role']=='FACULTY': clauses.append('faculty_id=%s'); args.append(g.user['faculty_id'])
    if g.user['role']=='HOD': clauses.append('d.department_id=%s' if kind=='departments' else 'department_id=%s'); args.append(g.user['department_id'])
    if clauses: sql+=' WHERE '+' AND '.join(clauses)
    if kind=='departments': sql+=' GROUP BY d.department_id,d.department_name'
    rows=db.query(sql,args)
    hidden={'student_id','programme_id','department_id','faculty_id','offering_id','registration_id','exam_id','semester_id','bill_id'}
    headers=[k for k in rows[0] if k not in hidden] if rows else []
    if request.args.get('format')=='csv':
        stream=io.StringIO(); writer=csv.writer(stream); writer.writerow(headers)
        for row in rows:
            cells=[]
            for key in headers:
                value=row[key]; value='' if value is None else str(value)
                if value.startswith(('=','+','-','@','\t','\r')): value="'"+value
                cells.append(value)
            writer.writerow(cells)
        return Response(stream.getvalue(),mimetype='text/csv',headers={'Content-Disposition':f'attachment; filename={kind}.csv'})
    return render_template('reports.html',title='Reports',reports={k:REPORTS[k] for k in allowed},kind=kind,rows=rows,headers=headers,threshold=cfg['attendance_threshold'])

@app.route('/users',methods=['GET','POST'])
@roles('ADMIN')
def users():
    if request.method=='POST':
        password=text('password')
        if len(password)<12: abort(400,'Use a password of at least 12 characters.')
        role=text('role')
        sid=integer('student_id') if role=='STUDENT' else None
        fid=integer('faculty_id') if role=='FACULTY' else None
        did=integer('department_id') if role=='HOD' else None
        with db.transaction() as con:
            db.execute('INSERT INTO app_user(username,password_hash,role,student_id,faculty_id,department_id) VALUES(%s,%s,%s,%s,%s,%s)',(text('username'),generate_password_hash(password),role,sid,fid,did),con)
            audit('create user',text('username'),con)
        flash('Account created.','success'); return redirect(url_for('users'))
    return render_template('users.html',title='User accounts',rows=db.query('SELECT username,role,student_id,faculty_id,department_id FROM app_user ORDER BY user_id'),students=db.query('SELECT student_id,full_name,registration_no FROM student'),faculty=options('faculty'),departments=options('departments'))

@app.get('/audit')
@roles('ADMIN')
def audit_page():
    rows=db.query('SELECT a.created_at,u.username,a.action,a.detail FROM audit_event a LEFT JOIN app_user u ON u.user_id=a.user_id ORDER BY event_id DESC LIMIT 300')
    return render_template('audit.html',title='Activity log',rows=rows)

@app.errorhandler(pymysql.MySQLError)
def database_error(error):
    code=error.args[0]
    messages={1062:'That record already exists. Check the unique code or number.',1451:'This record is used by other records and cannot be removed.',1452:'A selected related record no longer exists.',3819:'A value violates a database rule. Check dates, ranges and required statuses.',1048:'A required value is missing.',1406:'One of the entered values is too long.',1265:'A value has an invalid format.',1366:'A value has an invalid format.'}
    message=error.args[1] if code==1644 else messages.get(code,'The database could not save this operation. No partial form changes were saved.')
    app.logger.warning('Database operation failed (%s)',code)
    return render_template('error.html',title='Unable to save',message=message),400

@app.errorhandler(400)
@app.errorhandler(403)
@app.errorhandler(404)
@app.errorhandler(429)
def request_error(error):
    return render_template('error.html',title=str(error.code),message=error.description),error.code

if __name__=='__main__':
    from waitress import serve
    print('College management is running at http://127.0.0.1:5080',flush=True)
    serve(app,host='127.0.0.1',port=5080,threads=8)
