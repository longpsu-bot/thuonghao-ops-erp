SELECT
  s.id AS school_id,
  s.name AS school_name,
  s.default_students_num,
  s.default_teacher_num,
  d.student_portions,
  d.teacher_portions,
  s.display_order
FROM schools AS s
LEFT JOIN daily_orders AS d
  ON s.id = d.school_id
 AND d.service_date = DATE({{ datePicker2.value }})
WHERE s.is_active = true
ORDER BY
  s.display_order NULLS LAST,
  s.region_code NULLS LAST,
  s.name