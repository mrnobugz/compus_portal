from .models import Student, StudyGroup


def get_student_group_ids(student):
    return list(
        student.study_groups.values_list('id', flat=True)
    )


def sync_student_to_groups(student):
    """Assign student to all groups matching their department and course."""
    if not student.course_id:
        return
    groups = StudyGroup.objects.filter(
        department_id=student.department_id,
        course_id=student.course_id,
    )
    for group in groups:
        group.students.add(student)


def sync_group_members(group):
    """Add every student in the same department+course into this group."""
    if not group.course_id:
        return
    students = Student.objects.filter(
        department_id=group.department_id,
        course_id=group.course_id,
    )
    group.students.add(*students)
