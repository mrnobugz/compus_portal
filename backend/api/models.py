from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver


class Department(models.Model):
    name = models.CharField(max_length=100, unique=True)
    code = models.CharField(max_length=20, unique=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class Course(models.Model):
    department = models.ForeignKey(
        Department, on_delete=models.CASCADE, related_name='courses'
    )
    name = models.CharField(max_length=150)
    code = models.CharField(max_length=30)

    class Meta:
        ordering = ['name']
        unique_together = [['department', 'code']]

    def __str__(self):
        return f"{self.code} - {self.name}"


class Lecturer(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='lecturer_profile')
    department = models.ForeignKey(
        Department, on_delete=models.SET_NULL, null=True, blank=True, related_name='lecturers'
    )

    def __str__(self):
        return self.user.get_full_name() or self.user.username


class Student(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    student_id = models.CharField(max_length=20, unique=True)
    department = models.ForeignKey(
        Department, on_delete=models.PROTECT, related_name='students'
    )
    course = models.ForeignKey(
        Course, on_delete=models.PROTECT, related_name='students', null=True, blank=True
    )
    profile_picture = models.ImageField(upload_to='uploads/profiles/', blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=['department']),
            models.Index(fields=['course']),
            models.Index(fields=['created_at']),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.student_id}"


class StudyGroup(models.Model):
    name = models.CharField(max_length=150)
    department = models.ForeignKey(
        Department, on_delete=models.CASCADE, related_name='study_groups'
    )
    course = models.ForeignKey(
        Course, on_delete=models.CASCADE, related_name='study_groups'
    )
    lecturer = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='teaching_groups',
    )
    students = models.ManyToManyField(Student, related_name='study_groups', blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']
        indexes = [
            models.Index(fields=['department', 'course']),
        ]

    def __str__(self):
        return self.name


class Note(models.Model):
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    file = models.FileField(upload_to='uploads/notes/', blank=True, null=True)
    groups = models.ManyToManyField(StudyGroup, related_name='notes', blank=True)
    uploaded_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, related_name='uploaded_notes'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['-created_at'])]

    def __str__(self):
        return self.title

    @property
    def file_extension(self):
        if not self.file:
            return ''
        return self.file.name.rsplit('.', 1)[-1].lower()


class Assignment(models.Model):
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    file = models.FileField(upload_to='uploads/assignments/')
    due_date = models.DateField(null=True, blank=True)
    groups = models.ManyToManyField(StudyGroup, related_name='assignments')
    lecturer = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='posted_assignments'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['-created_at']), models.Index(fields=['due_date'])]

    def __str__(self):
        return self.title


class Book(models.Model):
    title = models.CharField(max_length=200)
    author = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    file = models.FileField(upload_to='uploads/books/', blank=True, null=True)
    cover_image = models.ImageField(upload_to='uploads/covers/', blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=['-created_at']),
            models.Index(fields=['author']),
        ]

    def __str__(self):
        return self.title


class SupportRequest(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('in_progress', 'In Progress'),
        ('resolved', 'Resolved'),
        ('closed', 'Closed'),
    ]

    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='support_requests')
    subject = models.CharField(max_length=200)
    issue = models.TextField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    staff_response = models.TextField(blank=True, default='')
    responded_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='support_responses',
    )
    responded_at = models.DateTimeField(null=True, blank=True)
    response_read_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=['status']),
            models.Index(fields=['-created_at']),
            models.Index(fields=['student', 'status']),
        ]

    def __str__(self):
        return f"{self.subject} - {self.student.user.username}"

    @property
    def has_staff_response(self):
        return bool(self.staff_response and self.staff_response.strip())

    @property
    def has_unread_response(self):
        return self.has_staff_response and self.response_read_at is None


class Announcement(models.Model):
    PRIORITY_CHOICES = [
        ('info', 'Info'),
        ('urgent', 'Urgent'),
    ]
    AUDIENCE_CHOICES = [
        ('all', 'Everyone'),
        ('students', 'Students'),
        ('lecturers', 'Lecturers'),
    ]

    title = models.CharField(max_length=200)
    body = models.TextField()
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES, default='info')
    audience = models.CharField(max_length=20, choices=AUDIENCE_CHOICES, default='students')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['-created_at', 'is_active'])]

    def __str__(self):
        return self.title


class Grade(models.Model):
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='grades')
    course = models.ForeignKey(
        Course, on_delete=models.SET_NULL, null=True, blank=True, related_name='grades'
    )
    assessment = models.CharField(max_length=150)
    score = models.DecimalField(max_digits=5, decimal_places=2)
    max_score = models.DecimalField(max_digits=5, decimal_places=2, default=100)
    term = models.CharField(max_length=50, blank=True, default='Current')
    recorded_at = models.DateField(auto_now_add=True)

    class Meta:
        ordering = ['-recorded_at']
        indexes = [models.Index(fields=['student', '-recorded_at'])]

    def __str__(self):
        return f"{self.student.user.username} - {self.assessment}"

    @property
    def percentage(self):
        if self.max_score:
            return round(float(self.score) / float(self.max_score) * 100, 1)
        return 0


class AttendanceRecord(models.Model):
    STATUS_CHOICES = [
        ('present', 'Present'),
        ('absent', 'Absent'),
        ('late', 'Late'),
        ('excused', 'Excused'),
    ]

    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='attendance')
    course = models.ForeignKey(
        Course, on_delete=models.SET_NULL, null=True, blank=True, related_name='attendance'
    )
    date = models.DateField()
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='present')
    notes = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ['-date']
        unique_together = [['student', 'course', 'date']]
        indexes = [models.Index(fields=['student', '-date'])]

    def __str__(self):
        return f"{self.student.user.username} - {self.date} ({self.status})"


@receiver(post_save, sender=Student)
def auto_assign_student_groups(sender, instance, **kwargs):
    from .group_utils import sync_student_to_groups
    sync_student_to_groups(instance)


@receiver(post_save, sender=StudyGroup)
def auto_sync_group_students(sender, instance, **kwargs):
    from .group_utils import sync_group_members
    sync_group_members(instance)
