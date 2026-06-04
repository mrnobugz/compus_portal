import calendar
import json
from datetime import timedelta

from django.db.models import Count
from django.db.models.functions import TruncMonth
from django.db import models
from django.utils import timezone

from .models import (
    Assignment,
    Book,
    Course,
    Note,
    Student,
    StudyGroup,
    SupportRequest,
    Grade,
    AttendanceRecord,
)


def _monthly_counts(queryset, months_back=6):
    now = timezone.now()
    start = (now.replace(day=1) - timedelta(days=30 * (months_back - 1))).replace(
        day=1, hour=0, minute=0, second=0, microsecond=0
    )
    rows = (
        queryset.filter(created_at__gte=start)
        .annotate(month=TruncMonth('created_at'))
        .values('month')
        .annotate(count=Count('id'))
        .order_by('month')
    )
    count_by_month = {
        (row['month'].year, row['month'].month): row['count']
        for row in rows
        if row['month']
    }
    labels, data = [], []
    for i in range(months_back - 1, -1, -1):
        month_date = now - timedelta(days=30 * i)
        key = (month_date.year, month_date.month)
        labels.append(calendar.month_abbr[month_date.month])
        data.append(count_by_month.get(key, 0))
    return labels, data


def build_dashboard_context():
    """Shared analytics context for admin index and dashboard view."""
    students_count = Student.objects.count()
    books_count = Book.objects.count()
    support_count = SupportRequest.objects.count()
    pending_count = SupportRequest.objects.filter(status='pending').count()
    groups_count = StudyGroup.objects.count()
    notes_count = Note.objects.count()
    assignments_count = Assignment.objects.count()
    courses_count = Course.objects.count()

    dept_stats = Student.objects.values('department__name').annotate(count=Count('id'))
    department_labels = [item['department__name'] or 'Unknown' for item in dept_stats]
    department_data = [item['count'] for item in dept_stats]
    if not department_labels:
        department_labels, department_data = ['No Data'], [0]

    course_stats = (
        Student.objects.filter(course__isnull=False)
        .values('course__code', 'course__name')
        .annotate(count=Count('id'))
    )
    course_labels = [
        f"{item['course__code']}" for item in course_stats
    ]
    course_data = [item['count'] for item in course_stats]
    if not course_labels:
        course_labels, course_data = ['No Data'], [0]

    status_stats = SupportRequest.objects.values('status').annotate(count=Count('id'))
    status_labels = [
        dict(SupportRequest.STATUS_CHOICES).get(item['status'], item['status'])
        for item in status_stats
    ]
    status_data = [item['count'] for item in status_stats]
    if not status_labels:
        status_labels, status_data = ['No Data'], [0]

    month_labels, month_data = _monthly_counts(Student.objects.all())
    trend_labels, trend_data = _monthly_counts(SupportRequest.objects.all())
    notes_labels, notes_data = _monthly_counts(Note.objects.all())

    grade_stats = (
        Grade.objects.values('course__code')
        .annotate(avg_score=models.Avg(models.F('score') * 100 / models.F('max_score')))
        .order_by('-avg_score')[:8]
    )
    grade_labels = [g['course__code'] or 'General' for g in grade_stats]
    grade_data = [round(float(g['avg_score'] or 0), 1) for g in grade_stats]
    if not grade_labels:
        grade_labels, grade_data = ['No Data'], [0]

    att_total = AttendanceRecord.objects.count()
    att_present = AttendanceRecord.objects.filter(
        status__in=['present', 'late', 'excused']
    ).count()
    attendance_rate = round(att_present / att_total * 100, 1) if att_total else 0

    return {
        'students_count': students_count,
        'books_count': books_count,
        'support_count': support_count,
        'pending_count': pending_count,
        'groups_count': groups_count,
        'notes_count': notes_count,
        'assignments_count': assignments_count,
        'courses_count': courses_count,
        'department_labels_json': json.dumps(department_labels),
        'department_data_json': json.dumps(department_data),
        'course_labels_json': json.dumps(course_labels),
        'course_data_json': json.dumps(course_data),
        'status_labels_json': json.dumps(status_labels),
        'status_data_json': json.dumps(status_data),
        'month_labels_json': json.dumps(month_labels),
        'month_data_json': json.dumps(month_data),
        'trend_labels_json': json.dumps(trend_labels),
        'trend_data_json': json.dumps(trend_data),
        'notes_labels_json': json.dumps(notes_labels),
        'notes_data_json': json.dumps(notes_data),
        'grade_labels_json': json.dumps(grade_labels),
        'grade_data_json': json.dumps(grade_data),
        'attendance_rate': attendance_rate,
    }
