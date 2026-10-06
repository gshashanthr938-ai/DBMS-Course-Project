import json
import os
from contextlib import contextmanager
from pathlib import Path
import pymysql
from pymysql.cursors import DictCursor

ROOT = Path(__file__).resolve().parent

def settings():
    path = Path(os.environ.get('COLLEGE_CONFIG', ROOT / '.local' / 'config.json'))
    if not path.exists():
        raise RuntimeError('Run setup.py before starting the application.')
    return json.loads(path.read_text())

def connect():
    cfg = settings()
    return pymysql.connect(host=cfg['host'], port=cfg['port'], user=cfg['user'],
        password=cfg['password'], database=cfg['database'], charset='utf8mb4',
        cursorclass=DictCursor, autocommit=True,
        init_command='SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED')

@contextmanager
def transaction():
    con = connect()
    try:
        con.begin()
        yield con
        con.commit()
    except Exception:
        con.rollback()
        raise
    finally:
        con.close()

def query(sql, args=(), one=False, con=None):
    own = con is None
    con = con or connect()
    try:
        with con.cursor() as cur:
            cur.execute(sql, args)
            return cur.fetchone() if one else cur.fetchall()
    finally:
        if own: con.close()

def execute(sql, args=(), con=None):
    own = con is None
    con = con or connect()
    try:
        with con.cursor() as cur:
            cur.execute(sql, args)
            return cur.lastrowid
    finally:
        if own: con.close()

def call(name, args):
    assert name in {'register_student','drop_registration','collect_payment'}
    with connect() as con:
        with con.cursor() as cur:
            cur.callproc(name,args)
            while cur.nextset(): pass
