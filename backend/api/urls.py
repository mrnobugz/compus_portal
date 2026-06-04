from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import StudentViewSet, BookViewSet, SupportRequestViewSet, UserViewSet
from .auth_views import register_student
from .group_views import (
    DepartmentViewSet,
    CourseViewSet,
    StudyGroupViewSet,
    NoteViewSet,
    AssignmentViewSet,
)
from .student_views import (
    AnnouncementViewSet,
    GradeViewSet,
    AttendanceRecordViewSet,
    StudentDashboardViewSet,
)
from .dashboard_views import admin_dashboard

router = DefaultRouter()
router.register(r'students', StudentViewSet)
router.register(r'books', BookViewSet)
router.register(r'support', SupportRequestViewSet)
router.register(r'users', UserViewSet)
router.register(r'departments', DepartmentViewSet)
router.register(r'courses', CourseViewSet)
router.register(r'groups', StudyGroupViewSet)
router.register(r'notes', NoteViewSet)
router.register(r'assignments', AssignmentViewSet)
router.register(r'announcements', AnnouncementViewSet)
router.register(r'grades', GradeViewSet)
router.register(r'attendance', AttendanceRecordViewSet)
router.register(r'dashboard', StudentDashboardViewSet, basename='student-dashboard')

urlpatterns = [
    path('', include(router.urls)),
    path('auth/register/', register_student, name='register_student'),
    path('dashboard/', admin_dashboard, name='admin_dashboard'),
]
