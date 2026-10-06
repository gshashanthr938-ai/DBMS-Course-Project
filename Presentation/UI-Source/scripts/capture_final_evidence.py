"""Capture real UI pages and a reversible insert/delete example on local MySQL.

Uses Flask's HTTP test client against the configured presentation database, then
renders the returned HTML in local headless Chrome. The temporary department is
created and removed through the same UI routes used by the browser.
"""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from app import app
import db

PRESENTATION = ROOT.parent
OUT = PRESENTATION / 'screenshots'
HTML = ROOT / '.local' / 'capture-html'
OUT.mkdir(parents=True, exist_ok=True)
HTML.mkdir(parents=True, exist_ok=True)
CHROME = Path(r'C:\Program Files\Google\Chrome\Application\chrome.exe')
if not CHROME.exists():
    raise RuntimeError('Chrome is needed to capture UI evidence on this computer.')

def capture(client, name, url):
    response = client.get(url)
    if response.status_code != 200:
        raise RuntimeError(f'{url} returned {response.status_code}')
    html = response.data.decode('utf-8')
    html = html.replace('href="/static/style.css"',
                        f'href="{(ROOT/"static"/"style.css").as_uri()}"')
    html = html.replace('src="/static/app.js"',
                        f'src="{(ROOT/"static"/"app.js").as_uri()}"')
    source = HTML / f'{name}.html'
    source.write_text(html, encoding='utf-8')
    subprocess.run([
        str(CHROME),'--headless=new','--disable-gpu','--hide-scrollbars',
        '--allow-file-access-from-files','--window-size=1440,1000',
        f'--screenshot={OUT/name}.png',source.as_uri()
    ],check=True,capture_output=True)

with app.test_client() as client:
    capture(client,'07-login','/login')
    with client.session_transaction() as sess:
        csrf = sess['csrf']
    signed_in = client.post('/login',data={
        'csrf':csrf,'username':'admin','password':'CollegeDemo!2026'
    })
    if signed_in.status_code != 302:
        raise RuntimeError('Demo admin login failed')
    with client.session_transaction() as sess:
        csrf = sess['csrf']

    capture(client,'08-students-view','/students')
    capture(client,'09-student-insert-form','/students/new')
    capture(client,'10-registrations','/registrations')
    capture(client,'11-user-accounts','/users')
    capture(client,'12-receipt','/receipts/1')

    before = db.query('SELECT department_id FROM department WHERE department_code=%s',
                      ('DEMO-QA',),one=True)
    if before:
        raise RuntimeError('DEMO-QA already exists; use a fresh demo database.')
    count_before = db.query('SELECT COUNT(*) AS n FROM department',one=True)['n']
    capture(client,'13-department-before-insert','/catalog/departments')
    created = client.post('/catalog/departments',data={
        'csrf':csrf,'action':'create','department_code':'DEMO-QA',
        'department_name':'Temporary demonstration department'
    })
    if created.status_code != 302:
        raise RuntimeError(f'Insert route returned {created.status_code}')
    row = db.query('SELECT department_id,department_code,department_name FROM department WHERE department_code=%s',
                   ('DEMO-QA',),one=True)
    if not row:
        raise RuntimeError('UI insert was not reflected in MySQL')
    count_after_insert = db.query('SELECT COUNT(*) AS n FROM department',one=True)['n']
    capture(client,'14-department-after-insert-before-delete','/catalog/departments')
    deleted = client.post('/catalog/departments',data={
        'csrf':csrf,'action':'delete','record_key':str(row['department_id'])
    })
    if deleted.status_code != 302:
        raise RuntimeError(f'Delete route returned {deleted.status_code}')
    remaining = db.query('SELECT department_id FROM department WHERE department_code=%s',
                         ('DEMO-QA',),one=True)
    count_after_delete = db.query('SELECT COUNT(*) AS n FROM department',one=True)['n']
    if remaining or (count_before,count_after_insert,count_after_delete)!=(5,6,5):
        raise RuntimeError('UI delete was not reflected in MySQL')
    capture(client,'15-department-after-delete','/catalog/departments')
    capture(client,'16-audit-log','/audit')

evidence = f'''Live UI and MySQL evidence - synthetic department DEMO-QA
Database: college_pbl_presentation, MySQL 8.0.46 on localhost:3308

SELECT COUNT(*) FROM department;  -- before UI insert: {count_before}
POST /catalog/departments action=create -- returned {created.status_code}
SELECT department_id,department_code,department_name FROM department
 WHERE department_code='DEMO-QA';
-- result: {row['department_id']} | {row['department_code']} | {row['department_name']}
SELECT COUNT(*) FROM department;  -- after UI insert: {count_after_insert}

POST /catalog/departments action=delete record_key={row['department_id']} -- returned {deleted.status_code}
SELECT department_id FROM department WHERE department_code='DEMO-QA';
-- result: 0 rows
SELECT COUNT(*) FROM department;  -- after UI delete: {count_after_delete}

Screenshots 13, 14 and 15 show the before, inserted, and deleted states.
The audit screen records the create and delete actions.
'''
(PRESENTATION / 'CRUD_Database_Evidence.txt').write_text(evidence,encoding='utf-8')
print(f'Captured UI evidence in {OUT}; counts: {count_before} -> {count_after_insert} -> {count_after_delete}')
