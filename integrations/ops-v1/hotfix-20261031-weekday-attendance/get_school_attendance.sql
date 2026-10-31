-- Replace only the existing Retool get_school_attendance query after the DB patch.
SELECT
  s.id AS school_id,
  s.name AS school_name,
  coalesce(s.default_students_weekday[extract(isodow from DATE({{ datePicker2.value }}))::int], s.default_students_num) AS default_students_num,
  coalesce(s.default_teachers_weekday[extract(isodow from DATE({{ datePicker2.value }}))::int], s.default_teacher_num) AS default_teacher_num,
  d.student_portions,
  d.teacher_portions,
  s.display_order
FROM public.schools AS s
LEFT JOIN public.daily_orders AS d
  ON s.id = d.school_id
 AND d.service_date = DATE({{ datePicker2.value }})
WHERE s.is_active = true
ORDER BY s.display_order NULLS LAST, s.region_code NULLS LAST, s.name;
