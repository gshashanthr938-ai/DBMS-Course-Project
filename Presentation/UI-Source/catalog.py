"""A fixed allow-list of editable entities and fields; never trust SQL identifiers from requests."""
def field(name,label,kind='text',source=None): return (name,label,kind,source)
CATALOG={
 'departments': ('Departments','department',['department_id'],[field('department_code','Code'),field('department_name','Department name')]),
 'programmes': ('Programmes','programme',['programme_id'],[field('department_id','Department','select','departments'),field('programme_code','Code'),field('programme_name','Programme name'),field('duration_terms','Duration in terms','number')]),
 'courses': ('Courses','course',['course_id'],[field('department_id','Department','select','departments'),field('course_code','Course code'),field('course_title','Course title'),field('credits','Credits','number')]),
 'faculty': ('Faculty','faculty',['faculty_id'],[field('department_id','Department','select','departments'),field('employee_no','Employee number'),field('full_name','Full name'),field('email','Email','email'),field('phone','Phone')]),
 'semesters': ('Semesters','semester',['semester_id'],[field('academic_year','Academic year'),field('term_name','Term name'),field('start_date','Start date','date'),field('end_date','End date','date')]),
 'curriculum': ('Programme curriculum','programme_course',['programme_id','course_id'],[field('programme_id','Programme','select','programmes'),field('course_id','Course','select','courses'),field('recommended_term','Recommended term','number'),field('course_type','Type','select','course_types')]),
 'guardians': ('Guardians','guardian',['guardian_id'],[field('full_name','Full name'),field('phone','Phone'),field('email','Email','email')]),
 'offerings': ('Course offerings','course_offering',['offering_id'],[field('course_id','Course','select','courses'),field('semester_id','Semester','select','semesters'),field('faculty_id','Faculty','select','faculty'),field('section_code','Section'),field('capacity','Capacity','number')]),
}
OPTION_SQL={
 'departments':'SELECT department_id id,department_name label FROM department ORDER BY label',
 'programmes':'SELECT programme_id id,programme_name label FROM programme ORDER BY label',
 'courses':'SELECT course_id id,CONCAT(course_code," · ",course_title) label FROM course ORDER BY label',
 'faculty':'SELECT faculty_id id,full_name label FROM faculty ORDER BY label',
 'semesters':'SELECT semester_id id,CONCAT(academic_year," ",term_name) label FROM semester ORDER BY start_date DESC',
 'guardians':'SELECT guardian_id id,CONCAT(full_name," · ",phone) label FROM guardian ORDER BY label',
}
