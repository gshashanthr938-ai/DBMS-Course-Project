"""Capture representative local UI pages for the project report."""
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from app import app

OUT=ROOT/'docs'/'screenshots'
SRC=OUT/'html'
OUT.mkdir(parents=True,exist_ok=True); SRC.mkdir(exist_ok=True)
chrome=Path(r'C:\Program Files\Google\Chrome\Application\chrome.exe')

def save(client,name,url):
    response=client.get(url)
    if response.status_code!=200: raise RuntimeError(f'{url} returned {response.status_code}')
    html=response.data.decode().replace('href="/static/style.css"',f'href="{(ROOT/"static"/"style.css").as_uri()}"').replace('src="/static/app.js"',f'src="{(ROOT/"static"/"app.js").as_uri()}"')
    source=SRC/f'{name}.html'; source.write_text(html,encoding='utf-8')
    subprocess.run([str(chrome),'--headless=new','--disable-gpu','--hide-scrollbars','--allow-file-access-from-files','--window-size=1440,1000',f'--screenshot={OUT/name}.png',source.as_uri()],check=True,capture_output=True)

with app.test_client() as client:
    client.get('/login')
    with client.session_transaction() as session: csrf=session['csrf']
    result=client.post('/login',data={'csrf':csrf,'username':'admin','password':'CollegeDemo!2026'})
    if result.status_code!=302: raise RuntimeError('Demo admin sign-in failed')
    save(client,'01-dashboard','/')
    save(client,'02-student-record','/students/1')
    save(client,'03-attendance','/attendance?offering=1&session_id=1')
    save(client,'04-examinations','/examinations?offering=1&exam=1')
    save(client,'05-fees','/fees')
    save(client,'06-reports','/reports?kind=attendance')
print(f'Captured six screens in {OUT}')
