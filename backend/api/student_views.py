from django.db import models
from django.utils import timezone
from rest_framework import viewsets, permissions
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import (
    Announcement,
    Grade,
    AttendanceRecord,
    Student,
    Assignment,
    SupportRequest,
)
from .serializers import (
    AnnouncementSerializer,
    GradeSerializer,
    AttendanceRecordSerializer,
)


def _get_student(user):
    try:
        return Student.objects.select_related('department', 'course').get(user=user)
    except Student.DoesNotExist:
        return None


class AnnouncementViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Announcement.objects.filter(is_active=True)
    serializer_class = AnnouncementSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = super().get_queryset()
        now = timezone.now()
        qs = qs.filter(
            models.Q(expires_at__isnull=True) | models.Q(expires_at__gt=now)
        )
        user = self.request.user
        from .models import Lecturer

        is_lecturer = Lecturer.objects.filter(user=user).exists() or user.is_staff
        if is_lecturer and not _get_student(user):
            return qs.filter(audience__in=['all', 'lecturers'])
        return qs.filter(audience__in=['all', 'students'])


class GradeViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Grade.objects.all()
    serializer_class = GradeSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.is_staff:
            return Grade.objects.select_related('course', 'student__user').all()
        student = _get_student(user)
        if not student:
            return Grade.objects.none()
        return Grade.objects.filter(student=student).select_related('course')


class AttendanceRecordViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = AttendanceRecord.objects.all()
    serializer_class = AttendanceRecordSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.is_staff:
            return AttendanceRecord.objects.select_related('course', 'student__user').all()
        student = _get_student(user)
        if not student:
            return AttendanceRecord.objects.none()
        return AttendanceRecord.objects.filter(student=student).select_related('course')

    @action(detail=False, methods=['get'])
    def summary(self, request):
        qs = self.get_queryset()
        total = qs.count()
        if total == 0:
            return Response({
                'total_sessions': 0,
                'present': 0,
                'absent': 0,
                'late': 0,
                'excused': 0,
                'attendance_rate': 0,
            })
        present = qs.filter(status='present').count()
        late = qs.filter(status='late').count()
        excused = qs.filter(status='excused').count()
        absent = qs.filter(status='absent').count()
        attended = present + late + excused
        rate = round(attended / total * 100, 1)
        return Response({
            'total_sessions': total,
            'present': present,
            'absent': absent,
            'late': late,
            'excused': excused,
            'attendance_rate': rate,
        })


class StudentDashboardViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]

    @action(detail=False, methods=['get'], url_path='summary')
    def summary(self, request):
        student = _get_student(request.user)
        now = timezone.now()
        ann_qs = Announcement.objects.filter(
            is_active=True, audience__in=['all', 'students']
        ).filter(
            models.Q(expires_at__isnull=True) | models.Q(expires_at__gt=now)
        )
        data = {
            'announcements_count': ann_qs.count(),
            'upcoming_assignments': 0,
            'open_support_requests': 0,
            'average_grade': None,
            'attendance_rate': None,
        }
        if not student:
            return Response(data)

        group_ids = list(student.study_groups.values_list('id', flat=True))
        if group_ids:
            from django.utils.timezone import localdate

            data['upcoming_assignments'] = Assignment.objects.filter(
                groups__id__in=group_ids,
                due_date__gte=localdate(),
            ).distinct().count()

        data['open_support_requests'] = SupportRequest.objects.filter(
            student=student,
            status__in=['pending', 'in_progress'],
        ).count()

        grades = Grade.objects.filter(student=student)
        if grades.exists():
            total_pct = sum(g.percentage for g in grades)
            data['average_grade'] = round(total_pct / grades.count(), 1)

        att = AttendanceRecord.objects.filter(student=student)
        att_total = att.count()
        if att_total:
            attended = att.filter(status__in=['present', 'late', 'excused']).count()
            data['attendance_rate'] = round(attended / att_total * 100, 1)

        return Response(data)
