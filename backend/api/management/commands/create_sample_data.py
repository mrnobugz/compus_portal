from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from api.models import (
    Department,
    Course,
    Lecturer,
    Student,
    StudyGroup,
    Note,
    Assignment,
    Book,
    SupportRequest,
    Announcement,
    Grade,
    AttendanceRecord,
)
from django.utils import timezone
from datetime import timedelta, date
import random


class Command(BaseCommand):
    help = 'Creates sample data for the Campus Portal'

    def handle(self, *args, **options):
        dept_data = [
            ('Computer Science', 'CS'),
            ('Engineering', 'ENG'),
            ('Business', 'BUS'),
            ('Arts', 'ART'),
            ('Medicine', 'MED'),
        ]
        departments = {}
        for name, code in dept_data:
            dept, _ = Department.objects.get_or_create(name=name, defaults={'code': code})
            departments[name] = dept

        courses = {}
        course_defs = [
            ('Computer Science', 'BSc Computer Science', 'BSC-CS'),
            ('Computer Science', 'MSc Software Engineering', 'MSC-SE'),
            ('Engineering', 'BEng Civil Engineering', 'BENG-CE'),
            ('Business', 'BBA Management', 'BBA-MGT'),
            ('Medicine', 'MBBS General Medicine', 'MBBS-GM'),
        ]
        for dept_name, course_name, code in course_defs:
            course, _ = Course.objects.get_or_create(
                department=departments[dept_name],
                code=code,
                defaults={'name': course_name},
            )
            courses[code] = course

        if not User.objects.filter(username='admin').exists():
            admin_user = User.objects.create_user(
                username='admin',
                email='admin@campus.edu',
                password='admin123',
                is_staff=True,
                is_superuser=True,
            )
            Student.objects.create(
                user=admin_user,
                student_id='ADMIN001',
                department=departments['Computer Science'],
                course=courses['BSC-CS'],
            )
            self.stdout.write(self.style.SUCCESS('Admin user created (admin / admin123)'))

        if not User.objects.filter(username='lecturer1').exists():
            lecturer_user = User.objects.create_user(
                username='lecturer1',
                email='lecturer1@campus.edu',
                password='lecturer123',
                first_name='Dr',
                last_name='Smith',
            )
            Lecturer.objects.create(
                user=lecturer_user,
                department=departments['Computer Science'],
            )
            self.stdout.write(self.style.SUCCESS('Lecturer user created (lecturer1 / lecturer123)'))

        first_names = ['John', 'Jane', 'Mike', 'Sarah', 'David']
        last_names = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones']
        dept_list = list(departments.values())
        course_list = list(courses.values())

        for i in range(20):
            username = f'student{i+1:03d}'
            dept = random.choice(dept_list)
            matching = [c for c in course_list if c.department_id == dept.id]
            course = random.choice(matching) if matching else course_list[0]
            if User.objects.filter(username=username).exists():
                user = User.objects.get(username=username)
                student = Student.objects.filter(user=user).first()
                if not student:
                    sid = f'STU{1000+i}'
                    if Student.objects.filter(student_id=sid).exists():
                        sid = f'STU-{username}'
                    student = Student.objects.create(
                        user=user,
                        student_id=sid,
                        department=dept,
                        course=course,
                    )
                elif not student.course_id:
                    student.department = dept
                    student.course = course
                    student.save(update_fields=['department', 'course', 'updated_at'])
                continue
            user = User.objects.create_user(
                username=username,
                email=f'{username}@campus.edu',
                password='password123',
                first_name=random.choice(first_names),
                last_name=random.choice(last_names),
            )
            Student.objects.create(
                user=user,
                student_id=f'STU{1000+i}',
                department=dept,
                course=course,
            )

        lecturer_user = User.objects.get(username='lecturer1')
        cs = departments['Computer Science']
        bsc = courses['BSC-CS']

        group, _ = StudyGroup.objects.get_or_create(
            name='BSc CS - Year 2 - Group A',
            department=cs,
            course=bsc,
            defaults={'lecturer': lecturer_user},
        )
        group.lecturer = lecturer_user
        group.save()
        from api.group_utils import sync_group_members
        sync_group_members(group)

        notes_data = [
            ('Introduction to Algorithms', 'Week 1 lecture notes'),
            ('Database Systems Overview', 'SQL and normalization summary'),
            ('Flutter Mobile Development', 'UI widgets and state management'),
        ]
        from django.core.files.base import ContentFile
        for title, desc in notes_data:
            if not Note.objects.filter(title=title).exists():
                note = Note(
                    title=title,
                    description=desc,
                    uploaded_by=lecturer_user,
                )
                note.file.save(
                    f'{title.replace(" ", "_")}.txt',
                    ContentFile(f'# {title}\n\n{desc}\n\nSample course notes content.'),
                    save=False,
                )
                note.save()
                note.groups.add(group)

        if not Assignment.objects.filter(title='Assignment 1 - Data Structures').exists():
            from django.core.files.base import ContentFile
            assignment = Assignment(
                title='Assignment 1 - Data Structures',
                description='Implement a binary search tree in Python.',
                due_date=date.today() + timedelta(days=14),
                lecturer=lecturer_user,
            )
            assignment.file.save(
                'assignment1.txt',
                ContentFile(b'Submit your BST implementation as a PDF or DOCX file.'),
                save=False,
            )
            assignment.save()
            assignment.groups.add(group)

        books = [
            {'title': 'Python Programming', 'author': 'John Smith', 'description': 'Learn Python'},
            {'title': 'Django for Beginners', 'author': 'Jane Doe', 'description': 'Web dev with Django'},
        ]
        for book_data in books:
            if not Book.objects.filter(title=book_data['title']).exists():
                Book.objects.create(**book_data)

        sample_student = Student.objects.filter(user__username='student001').first()
        if sample_student:
            admin_user = User.objects.filter(username='admin').first()
            ticket, created = SupportRequest.objects.get_or_create(
                student=sample_student,
                subject='Cannot access course notes',
                defaults={
                    'issue': (
                        'I logged in but some notes show "No file attached". '
                        'Please help me access PDF materials for my group.'
                    ),
                    'status': 'resolved',
                    'staff_response': (
                        'Hi! We refreshed your group membership. Please pull down to '
                        'refresh the Notes tab. If a note still fails, use Server settings '
                        'to confirm your phone points to the campus server on the same Wi‑Fi. '
                        'Contact us again if the issue persists.'
                    ),
                    'responded_by': admin_user,
                    'responded_at': timezone.now(),
                },
            )
            if not created and admin_user and not ticket.staff_response:
                ticket.staff_response = (
                    'Your request is being reviewed. Check back here for updates from staff.'
                )
                ticket.responded_by = admin_user
                ticket.responded_at = timezone.now()
                ticket.status = 'in_progress'
                ticket.save()

        students = Student.objects.exclude(user__username='admin')[:5]
        for student in students:
            if student == sample_student:
                continue
            if random.choice([True, False]):
                SupportRequest.objects.get_or_create(
                    student=student,
                    subject='Cannot access notes',
                    defaults={
                        'issue': 'Sample support request.',
                        'status': 'pending',
                    },
                )

        announcements = [
            ('Welcome to Campus Portal', 'Access notes, assignments, and library resources from your phone.', 'info'),
            ('Assignment deadlines', 'Check the Tasks tab weekly for upcoming due dates.', 'urgent'),
        ]
        for title, body, priority in announcements:
            Announcement.objects.get_or_create(
                title=title,
                defaults={'body': body, 'priority': priority, 'audience': 'students'},
            )

        sample_student = Student.objects.filter(user__username='student001').first()
        if sample_student and sample_student.course:
            grade_defs = [
                ('Midterm Exam', 78, 100),
                ('Quiz 1', 42, 50),
                ('Project', 88, 100),
            ]
            for name, score, max_score in grade_defs:
                Grade.objects.get_or_create(
                    student=sample_student,
                    assessment=name,
                    term='Semester 1',
                    defaults={
                        'score': score,
                        'max_score': max_score,
                        'course': sample_student.course,
                    },
                )
            for i in range(14):
                day = date.today() - timedelta(days=i)
                status = random.choice(['present', 'present', 'present', 'late', 'absent'])
                AttendanceRecord.objects.get_or_create(
                    student=sample_student,
                    course=sample_student.course,
                    date=day,
                    defaults={'status': status},
                )

        self.stdout.write(self.style.SUCCESS('Sample data ready.'))
        self.stdout.write('Students: student001 / password123')
        self.stdout.write('Lecturer: lecturer1 / lecturer123')
        self.stdout.write('Admin: admin / admin123')
