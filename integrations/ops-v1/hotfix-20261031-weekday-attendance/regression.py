import json
from pathlib import Path
import subprocess
import unittest
import re
import hashlib
import uuid

ROOT = Path(__file__).parent
CONTAINER = 'supabase_db_thuonghao-ops-erp'
DATABASE = 'ops_v1_weekday_test_'+uuid.uuid4().hex[:12]
MENU = ROOT.parent/'hotfix-20261031-menu-reset'
BASELINE = re.findall(r'CREATE OR REPLACE FUNCTION[\s\S]*?\$function\$;', (ROOT/'rollback.sql').read_text(encoding='utf-8'))
FIXTURE = json.loads((ROOT / 'source-fixture.json').read_text(encoding='utf-8'))

def sql(query):
    result = subprocess.run(['docker', 'exec', '-i', CONTAINER, 'psql', '-X', '-U', 'postgres', '-d', DATABASE, '-v', 'ON_ERROR_STOP=1', '-Atq'], input=query, capture_output=True, encoding='utf-8')
    if result.returncode:
        raise RuntimeError(result.stderr)
    return result.stdout.strip()

def bootstrap():
    fixture = (MENU/'fixture.sql').read_text(encoding='utf-8').replace('create temp ', 'create ').replace('pg_temp.', 'public.')
    sql(fixture)
    sql("CREATE SCHEMA auth; CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS 'select null::uuid';")
    sql('ALTER TABLE public.schools ADD COLUMN name text, ADD COLUMN is_active boolean NOT NULL DEFAULT true, ADD COLUMN display_order integer, ADD COLUMN region_code smallint;')
    for r in json.loads((ROOT/'fixture-schools.json').read_text(encoding='utf-8')):
        students = 'NULL' if r['students'] is None else str(r['students'])
        teachers = 'NULL' if r['teachers'] is None else str(r['teachers'])
        name = r['name'].replace("'", "''")
        sql(f"INSERT INTO schools(id,name,default_students_num,default_teacher_num) VALUES ({r['id']},'{name}',{students},{teachers});")
    for definition in BASELINE:
        sql(definition)
    sql('CREATE TRIGGER trg_daily_orders_fill_default_portions BEFORE INSERT OR UPDATE ON daily_orders FOR EACH ROW EXECUTE FUNCTION daily_orders_fill_default_portions(); CREATE TRIGGER trg_schools_sync_default_attendance_incoming AFTER UPDATE OF default_students_num,default_teacher_num ON schools FOR EACH ROW EXECUTE FUNCTION schools_sync_default_attendance_incoming();')
    sql('CREATE TABLE expected(service_date date,school_id bigint,students smallint,teachers smallint);')
    values = ','.join(f"('{r['date']}',{r['school_id']},{r['students']},{r['teachers']})" for r in FIXTURE)
    sql('INSERT INTO expected VALUES '+values+';')

def seed(method):
    sql('TRUNCATE daily_order_dishes,daily_orders RESTART IDENTITY;')
    if method == 'insert':
        sql('INSERT INTO daily_orders(service_date,school_id) SELECT service_date,school_id FROM expected;')
    else:
        sql(f"SELECT count(*) FROM {method}((SELECT jsonb_agg(jsonb_build_object('service_date',service_date,'school_id',school_id)) FROM expected));")

class WeekdayDefaultsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        bootstrap()
        before = sql('SELECT jsonb_agg(to_jsonb(d) ORDER BY id) FROM daily_orders d;')
        patch = (ROOT/'apply.sql').read_text(encoding='utf-8')
        assert len(BASELINE) == 7
        tampered = patch.replace('-- POSTFLIGHT:', 'UPDATE public.actual_need_overrides SET qty_actual=999;\n-- POSTFLIGHT:')
        try:
            sql(tampered)
            raise AssertionError('Existing-data corruption was accepted')
        except RuntimeError as error:
            assert 'OPS_V1_EXISTING_DATA_CHANGED' in str(error), str(error)
        assert sql("SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='schools' AND column_name='default_students_weekday';") == '0'
        assert sql('SELECT jsonb_agg(to_jsonb(d) ORDER BY id) FROM daily_orders d;') == before
        assert sql('SELECT bool_and(qty_actual<999) FROM actual_need_overrides;') == 't'
        sql(patch)
        assert sql('SELECT jsonb_agg(to_jsonb(d) ORDER BY id) FROM daily_orders d;') == before

    def test_00_menu_reset_regressions_remain_passing(self):
        regression = (MENU/'regression.sql').read_text(encoding='utf-8').replace('pg_temp.', 'public.')
        output = sql('BEGIN;\n'+regression+'\nROLLBACK;')
        self.assertEqual(output.count('PASS '), 9)

    def assert_expected(self):
        self.assertEqual(sql('SELECT count(*) FROM daily_orders;'), '170')
        self.assertEqual(sql('''SELECT count(*) FROM daily_orders d JOIN expected e USING(service_date,school_id)
WHERE d.student_portions IS DISTINCT FROM e.students OR d.teacher_portions IS DISTINCT FROM e.teachers;'''), '0')

    def test_01_direct_insert_all_170_source_rows(self):
        seed('insert')
        self.assert_expected()

    def test_02_upsert_rpc_all_170_source_rows(self):
        seed('fn_upsert_daily_orders')
        self.assert_expected()

    def test_03_menu_rpc_all_170_source_rows(self):
        seed('fn_save_daily_menus')
        self.assert_expected()

    def test_04_explicit_zero_and_manual_counts_survive_menu_resync(self):
        seed('fn_save_daily_menus')
        sql("UPDATE daily_orders SET student_portions=123,teacher_portions=0 WHERE school_id=24 AND service_date='2026-11-02';")
        sql("SELECT fn_save_daily_menus('[{\"school_id\":24,\"service_date\":\"2026-11-02\"}]');")
        self.assertEqual(sql("SELECT student_portions||','||teacher_portions FROM daily_orders WHERE school_id=24 AND service_date='2026-11-02';"), '123,0')
        sql("SELECT fn_save_daily_menus('[{\"school_id\":24,\"service_date\":\"2026-11-02\",\"student_portions\":0,\"teacher_portions\":7}]');")
        self.assertEqual(sql("SELECT student_portions||','||teacher_portions FROM daily_orders WHERE school_id=24 AND service_date='2026-11-02';"), '0,7')

    def test_05_next_week_and_weekend(self):
        sql('TRUNCATE daily_order_dishes,daily_orders RESTART IDENTITY;')
        sql("INSERT INTO daily_orders(service_date,school_id) VALUES ('2026-11-13',9),('2026-11-14',9);")
        self.assertEqual(sql("SELECT student_portions||','||teacher_portions FROM daily_orders WHERE service_date='2026-11-13';"), '135,15')
        self.assertEqual(sql("SELECT student_portions||','||teacher_portions FROM daily_orders WHERE service_date='2026-11-14';"), '260,20')

    def test_06_scalar_default_sync_keeps_configured_weekdays(self):
        sql('TRUNCATE daily_order_dishes,daily_orders RESTART IDENTITY;')
        sql("INSERT INTO daily_orders(service_date,school_id,student_portions,teacher_portions) VALUES (date_trunc('week',current_date)::date,24,675,40),(date_trunc('week',current_date)::date+5,24,675,40); UPDATE schools SET default_students_num=676,default_teacher_num=41 WHERE id=24;")
        self.assertEqual(sql("SELECT student_portions||','||teacher_portions FROM daily_orders WHERE extract(isodow from service_date)=1;"), '675,40')
        self.assertEqual(sql("SELECT student_portions||','||teacher_portions FROM daily_orders WHERE extract(isodow from service_date)=6;"), '676,41')
        sql('UPDATE schools SET default_students_num=675,default_teacher_num=40 WHERE id=24;')

    def test_07_rejects_bad_arrays(self):
        self.assertEqual(sql("SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='schools' AND column_name IN ('default_students_weekday','default_teachers_weekday');"), '2')
        for field in ['default_students_weekday','default_teachers_weekday']:
            for value in ["ARRAY[-1,2,3,4,5]", "ARRAY[1,2,3,4]", "ARRAY[1,2,NULL,4,5]", "ARRAY[[1,2,3,4,5]]", "'[0:4]={1,2,3,4,5}'::smallint[]", "ARRAY[]::smallint[]"]:
                with self.assertRaises(RuntimeError):
                    sql(f'BEGIN; UPDATE schools SET {field}={value} WHERE id=24; ROLLBACK;')

    def test_08_manual_insert_and_existing_upsert(self):
        sql('TRUNCATE daily_order_dishes,daily_orders RESTART IDENTITY;')
        sql("INSERT INTO daily_orders(service_date,school_id,student_portions,teacher_portions) VALUES ('2026-11-06',9,0,7);")
        sql("SELECT * FROM fn_upsert_daily_orders('[{\"school_id\":9,\"service_date\":\"2026-11-06\"}]');")
        self.assertEqual(sql('SELECT student_portions||\',\'||teacher_portions FROM daily_orders;'), '0,7')

    def test_09_unconfigured_school_falls_back(self):
        sql('INSERT INTO schools(id,default_students_num,default_teacher_num) VALUES(999,19,2);')
        sql("INSERT INTO daily_orders(service_date,school_id) VALUES ('2026-11-06',999);")
        self.assertEqual(sql('SELECT student_portions||\',\'||teacher_portions FROM daily_orders WHERE school_id=999;'), '19,2')

    def test_10_retool_defaults_match_all_sources(self):
        query = (ROOT / 'get_school_attendance.sql').read_text(encoding='utf-8')
        for service_date in sorted({r['date'] for r in FIXTURE}):
            actual_query = query.replace('{{ datePicker2.value }}', "'"+service_date+"'").strip().rstrip(';')
            count = sql('SELECT count(*) FROM ('+actual_query+") q JOIN expected e ON e.school_id=q.school_id AND e.service_date='"+service_date+"' WHERE q.default_students_num IS DISTINCT FROM e.students OR q.default_teacher_num IS DISTINCT FROM e.teachers;")
            self.assertEqual(count, '0')

    def test_11_reapplying_stops_without_changing_data(self):
        before = sql('SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM schools s;')
        with self.assertRaisesRegex(RuntimeError, 'OPS_V1_WEEKDAY_SOURCE_MISMATCH'):
            sql((ROOT / 'apply.sql').read_text(encoding='utf-8'))
        self.assertEqual(sql('SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM schools s;'), before)

    def test_99_rollback_restores_original_functions(self):
        before = sql('SELECT jsonb_agg(to_jsonb(d) ORDER BY id) FROM daily_orders d;')
        sql((ROOT / 'rollback.sql').read_text(encoding='utf-8'))
        self.assertEqual(sql('SELECT jsonb_agg(to_jsonb(d) ORDER BY id) FROM daily_orders d;'), before)
        self.assertEqual(sql("SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='schools' AND column_name IN ('default_students_weekday','default_teachers_weekday');"), '0')
        for definition in BASELINE:
            name = re.search(r'FUNCTION public\.(\w+)\(',definition).group(1)
            expected = hashlib.md5(definition.split('$function$')[1].replace('\r\n','\n').encode('utf-8')).hexdigest()
            actual = sql("SELECT md5(replace(prosrc,chr(13),'')) FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname='"+name+"';")
            self.assertEqual(actual, expected)
        query = (ROOT / 'get_school_attendance.rollback.sql').read_text(encoding='utf-8').replace('{{ datePicker2.value }}', "'2026-11-06'")
        sql(query)

if __name__ == '__main__':
    assert re.fullmatch(r'ops_v1_weekday_test_[0-9a-f]{12}', DATABASE)
    subprocess.run(['docker','exec',CONTAINER,'createdb','-U','postgres',DATABASE],check=True)
    try:
        unittest.main(verbosity=2)
    finally:
        subprocess.run(['docker','exec',CONTAINER,'dropdb','-U','postgres',DATABASE],check=True)
