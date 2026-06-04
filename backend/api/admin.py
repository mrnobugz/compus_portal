from django.contrib import admin
from django.contrib.auth.models import Group, User
from django.utils import timezone
from django.utils.html import format_html

from campus_portal.admin_site import campus_admin_site
from .models import (
    Assignment,
    Book,
    Course,
    Department,
    Lecturer,
    Note,
    Student,
    StudyGroup,
    SupportRequest,
    Announcement,
    Grade,
    AttendanceRecord,
)


class CampusModelAdmin(admin.ModelAdmin):
    """Base admin with campus styling on all forms and lists."""

    class Media:
        css = {'all': ('campus/campus_admin.css',)}


@admin.register(Department, site=campus_admin_site)
class DepartmentAdmin(CampusModelAdmin):
    list_display = ['name', 'code']
    search_fields = ['name', 'code']


@admin.register(Course, site=campus_admin_site)
class CourseAdmin(CampusModelAdmin):
    list_display = ['code', 'name', 'department']
    list_filter = ['department']
    search_fields = ['name', 'code']


@admin.register(Lecturer, site=campus_admin_site)
class LecturerAdmin(CampusModelAdmin):
    list_display = ['user', 'department']
    search_fields = ['user__username', 'user__email']
    autocomplete_fields = ['user']


@admin.register(Student, site=campus_admin_site)
class StudentAdmin(CampusModelAdmin):
    list_display = ['user', 'student_id', 'department', 'course', 'group_count', 'created_at']
    list_filter = ['department', 'course']
    search_fields = ['user__username', 'student_id']
    autocomplete_fields = ['user']

    @admin.display(description='Groups')
    def group_count(self, obj):
        return obj.study_groups.count()


@admin.register(StudyGroup, site=campus_admin_site)
class StudyGroupAdmin(CampusModelAdmin):
    list_display = ['name', 'department', 'course', 'lecturer', 'member_count']
    list_filter = ['department', 'course']
    search_fields = ['name']
    filter_horizontal = ['students']
    autocomplete_fields = ['lecturer']

    @admin.display(description='Students')
    def member_count(self, obj):
        return obj.students.count()


@admin.register(Note, site=campus_admin_site)
class NoteAdmin(CampusModelAdmin):
    list_display = ['title', 'uploaded_by', 'group_list', 'created_at']
    filter_horizontal = ['groups']
    search_fields = ['title']
    list_filter = ['created_at']

    @admin.display(description='Groups')
    def group_list(self, obj):
        names = list(obj.groups.values_list('name', flat=True)[:3])
        if obj.groups.count() > 3:
            names.append('…')
        return ', '.join(names) or '—'


@admin.register(Assignment, site=campus_admin_site)
class AssignmentAdmin(CampusModelAdmin):
    list_display = ['title', 'lecturer', 'due_date', 'group_list', 'created_at']
    list_filter = ['due_date', 'created_at']
    filter_horizontal = ['groups']
    search_fields = ['title']

    @admin.display(description='Groups')
    def group_list(self, obj):
        return ', '.join(obj.groups.values_list('name', flat=True)[:3]) or '—'


@admin.register(Book, site=campus_admin_site)
class BookAdmin(CampusModelAdmin):
    list_display = ['title', 'author', 'has_file', 'created_at']
    search_fields = ['title', 'author']
    list_filter = ['created_at']

    @admin.display(boolean=True, description='File')
    def has_file(self, obj):
        return bool(obj.file)


@admin.register(SupportRequest, site=campus_admin_site)
class SupportRequestAdmin(CampusModelAdmin):
    list_display = ['subject', 'student', 'status_badge', 'response_badge', 'created_at']
    search_fields = ['subject', 'issue', 'staff_response', 'student__user__username']
    list_filter = ['status', 'created_at']
    readonly_fields = ['responded_by', 'responded_at', 'response_read_at', 'created_at', 'updated_at']
    fieldsets = (
        (None, {
            'fields': ('student', 'subject', 'issue', 'status'),
        }),
        ('Staff response (visible to student in app)', {
            'fields': ('staff_response', 'responded_by', 'responded_at', 'response_read_at'),
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
        }),
    )

    @admin.display(description='Status')
    def status_badge(self, obj):
        css = {
            'pending': 'badge--pending',
            'in_progress': 'badge--in_progress',
            'resolved': 'badge--resolved',
            'closed': 'badge--closed',
        }.get(obj.status, '')
        label = dict(SupportRequest.STATUS_CHOICES).get(obj.status, obj.status)
        return format_html('<span class="badge {}">{}</span>', css, label)

    @admin.display(description='Reply')
    def response_badge(self, obj):
        if obj.has_staff_response:
            if obj.has_unread_response:
                return format_html('<span class="badge badge--pending">Unread by student</span>')
            return format_html('<span class="badge badge--resolved">Sent</span>')
        return format_html('<span class="badge">—</span>')

    def save_model(self, request, obj, form, change):
        response_changed = change and 'staff_response' in form.changed_data
        if obj.staff_response and obj.staff_response.strip():
            if response_changed or not obj.responded_at:
                obj.responded_by = request.user
                obj.responded_at = timezone.now()
                obj.response_read_at = None
            if obj.status == 'pending':
                obj.status = 'in_progress'
        super().save_model(request, obj, form, change)


@admin.register(Announcement, site=campus_admin_site)
class AnnouncementAdmin(CampusModelAdmin):
    list_display = ['title', 'priority', 'audience', 'is_active', 'created_at']
    list_filter = ['priority', 'audience', 'is_active']
    search_fields = ['title', 'body']


@admin.register(Grade, site=campus_admin_site)
class GradeAdmin(CampusModelAdmin):
    list_display = ['student', 'assessment', 'score', 'max_score', 'course', 'term', 'recorded_at']
    list_filter = ['term', 'course']
    search_fields = ['student__user__username', 'assessment']
    autocomplete_fields = ['student']


@admin.register(AttendanceRecord, site=campus_admin_site)
class AttendanceRecordAdmin(CampusModelAdmin):
    list_display = ['student', 'date', 'status', 'course']
    list_filter = ['status', 'date', 'course']
    search_fields = ['student__user__username']
    autocomplete_fields = ['student']


class UserAdmin(CampusModelAdmin):
    list_display = ['username', 'email', 'first_name', 'last_name', 'is_staff']
    list_filter = ['is_staff', 'is_superuser']
    search_fields = ['username', 'email', 'first_name', 'last_name']


class GroupAdmin(CampusModelAdmin):
    search_fields = ['name']


campus_admin_site.register(User, UserAdmin)
campus_admin_site.register(Group, GroupAdmin)
