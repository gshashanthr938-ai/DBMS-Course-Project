"""Set up the exact presentation database on this project's private MySQL server.

Run automatically by start.ps1 on a fresh checkout. Existing databases are never
reset. Passwords are written only to the ignored .local directory.
"""
import json
import secrets
from pathlib import Path

import pymysql

from setup import sql_statements


ROOT = Path(__file__).resolve().parent
LOCAL = ROOT / '.local'
DATABASE = 'college_pbl_presentation'
USER = 'college_app'
SQL = ROOT.parent / 'DBMS_Course_Project_All_Commands.sql'


def main():
    LOCAL.mkdir(exist_ok=True)
    admin_path = LOCAL / 'admin.json'
    admin = json.loads(admin_path.read_text(encoding='utf-8')) if admin_path.exists() else {
        'host': '127.0.0.1', 'port': 3308, 'password': ''
    }
    connection = pymysql.connect(
        host=admin['host'], port=admin['port'], user='root',
        password=admin['password'], autocommit=True, charset='utf8mb4',
    )
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT @@datadir')
            if Path(cursor.fetchone()[0]).resolve() != (LOCAL / 'mysql-data').resolve():
                raise RuntimeError('Refusing to modify a MySQL server outside this project.')
            cursor.execute('SHOW DATABASES LIKE %s', (DATABASE,))
            if cursor.fetchone():
                raise RuntimeError(f'{DATABASE} already exists. Setup never overwrites it.')

            for statement in sql_statements(SQL.read_text(encoding='utf-8')):
                cursor.execute(statement)

            password = secrets.token_urlsafe(32)
            cursor.execute(
                f"CREATE USER IF NOT EXISTS '{USER}'@'127.0.0.1' "
                'IDENTIFIED WITH mysql_native_password BY %s', (password,)
            )
            cursor.execute(
                f"ALTER USER '{USER}'@'127.0.0.1' "
                'IDENTIFIED WITH mysql_native_password BY %s', (password,)
            )
            cursor.execute(f"REVOKE ALL PRIVILEGES, GRANT OPTION FROM '{USER}'@'127.0.0.1'")
            cursor.execute(f"GRANT SELECT ON `{DATABASE}`.* TO '{USER}'@'127.0.0.1'")
            editable = (
                'department', 'programme', 'course', 'faculty', 'semester', 'student',
                'guardian', 'student_guardian', 'programme_course', 'course_offering',
                'class_session', 'attendance', 'examination', 'exam_result',
            )
            for table in editable:
                cursor.execute(
                    f"GRANT INSERT,UPDATE,DELETE ON `{DATABASE}`.`{table}` "
                    f"TO '{USER}'@'127.0.0.1'"
                )
            for table in ('fee_bill', 'grade'):
                cursor.execute(
                    f"GRANT INSERT,DELETE ON `{DATABASE}`.`{table}` "
                    f"TO '{USER}'@'127.0.0.1'"
                )
            for table in ('audit_event', 'app_user'):
                cursor.execute(
                    f"GRANT INSERT ON `{DATABASE}`.`{table}` TO '{USER}'@'127.0.0.1'"
                )
            for procedure in ('register_student', 'drop_registration', 'collect_payment'):
                cursor.execute(
                    f"GRANT EXECUTE ON PROCEDURE `{DATABASE}`.`{procedure}` "
                    f"TO '{USER}'@'127.0.0.1'"
                )

            if not admin['password']:
                admin['password'] = secrets.token_urlsafe(32)
                cursor.execute(
                    "ALTER USER 'root'@'localhost' "
                    'IDENTIFIED WITH mysql_native_password BY %s',
                    (admin['password'],),
                )
                admin_path.write_text(json.dumps(admin, indent=2), encoding='utf-8')

        config = {
            'host': admin['host'], 'port': admin['port'], 'database': DATABASE,
            'user': USER, 'password': password,
            'secret_key': secrets.token_hex(32), 'attendance_threshold': 75,
        }
        (LOCAL / 'config.json').write_text(json.dumps(config, indent=2), encoding='utf-8')
    finally:
        connection.close()

    print(f'Created {DATABASE}, with at least eleven rows in every table.')
    print('App configuration saved in ignored .local/config.json.')


if __name__ == '__main__':
    main()
