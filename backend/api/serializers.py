from rest_framework import serializers
from django.contrib.auth.models import User
from .models import (
    Department,
    Course,
    Student,
    StudyGroup,
    Note,
    Assignment,
    Book,
    SupportRequest,
    Lecturer,
    Announcement,
    Grade,
    AttendanceRecord,
)


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name']


class DepartmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Department
        fields = ['id', 'name', 'code']


class CourseSerializer(serializers.ModelSerializer):
    department_name = serializers.CharField(source='department.name', read_only=True)

    class Meta:
        model = Course
        fields = ['id', 'department', 'department_name', 'name', 'code']


class StudyGroupSerializer(serializers.ModelSerializer):
    department_name = serializers.CharField(source='department.name', read_only=True)
    course_name = serializers.CharField(source='course.name', read_only=True)
    course_code = serializers.CharField(source='course.code', read_only=True)
    lecturer_name = serializers.SerializerMethodField()
    student_count = serializers.SerializerMethodField()

    class Meta:
        model = StudyGroup
        fields = [
            'id', 'name', 'department', 'department_name',
            'course', 'course_name', 'course_code',
            'lecturer', 'lecturer_name', 'student_count', 'created_at',
        ]

    def get_lecturer_name(self, obj):
        if obj.lecturer:
            return obj.lecturer.get_full_name() or obj.lecturer.username
        return None

    def get_student_count(self, obj):
        return obj.students.count()


class StudentSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.CharField(source='user.email', read_only=True)
    department_name = serializers.CharField(source='department.name', read_only=True)
    course_name = serializers.CharField(source='course.name', read_only=True)
    profile_picture_url = serializers.SerializerMethodField()
    group_names = serializers.SerializerMethodField()

    class Meta:
        model = Student
        fields = [
            'id', 'user', 'username', 'email', 'student_id',
            'department', 'department_name', 'course', 'course_name',
            'group_names', 'profile_picture', 'profile_picture_url',
            'created_at', 'updated_at',
        ]

    def get_profile_picture_url(self, obj):
        if obj.profile_picture:
            return obj.profile_picture.url
        return None

    def get_group_names(self, obj):
        return list(obj.study_groups.values_list('name', flat=True))


class NoteListSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()
    file_type = serializers.CharField(source='file_extension', read_only=True)
    group_names = serializers.SerializerMethodField()

    class Meta:
        model = Note
        fields = [
            'id', 'title', 'description', 'file_url', 'file_type',
            'group_names', 'created_at',
        ]

    def get_file_url(self, obj):
        if obj.file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None

    def get_group_names(self, obj):
        return list(obj.groups.values_list('name', flat=True))


class NoteSerializer(NoteListSerializer):
    class Meta(NoteListSerializer.Meta):
        fields = NoteListSerializer.Meta.fields + ['updated_at']


class AssignmentListSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()
    lecturer_name = serializers.SerializerMethodField()
    group_names = serializers.SerializerMethodField()

    class Meta:
        model = Assignment
        fields = [
            'id', 'title', 'description', 'file_url', 'due_date',
            'lecturer_name', 'group_names', 'created_at',
        ]

    def get_file_url(self, obj):
        request = self.context.get('request')
        if request:
            return request.build_absolute_uri(obj.file.url)
        return obj.file.url

    def get_lecturer_name(self, obj):
        return obj.lecturer.get_full_name() or obj.lecturer.username

    def get_group_names(self, obj):
        return list(obj.groups.values_list('name', flat=True))


class AssignmentSerializer(AssignmentListSerializer):
    class Meta(AssignmentListSerializer.Meta):
        fields = AssignmentListSerializer.Meta.fields + ['updated_at']


class AssignmentCreateSerializer(serializers.ModelSerializer):
    group_ids = serializers.ListField(
        child=serializers.IntegerField(), write_only=True, min_length=1
    )

    class Meta:
        model = Assignment
        fields = ['title', 'description', 'file', 'due_date', 'group_ids']

    def create(self, validated_data):
        group_ids = validated_data.pop('group_ids')
        assignment = Assignment.objects.create(**validated_data)
        assignment.groups.set(group_ids)
        return assignment


class BookListSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()
    cover_image_url = serializers.SerializerMethodField()

    class Meta:
        model = Book
        fields = [
            'id', 'title', 'author', 'description',
            'file_url', 'cover_image_url', 'created_at',
        ]

    def get_file_url(self, obj):
        if obj.file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None

    def get_cover_image_url(self, obj):
        if obj.cover_image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.cover_image.url)
            return obj.cover_image.url
        return None


class BookSerializer(BookListSerializer):
    class Meta(BookListSerializer.Meta):
        fields = BookListSerializer.Meta.fields + [
            'file', 'cover_image', 'updated_at',
        ]


class SupportRequestSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source='student.user.username', read_only=True)
    responded_by_name = serializers.SerializerMethodField()
    has_unread_response = serializers.SerializerMethodField()
    has_staff_response = serializers.SerializerMethodField()

    class Meta:
        model = SupportRequest
        fields = [
            'id', 'student', 'student_name', 'subject', 'issue',
            'status', 'staff_response', 'responded_by_name', 'responded_at',
            'has_unread_response', 'has_staff_response',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'student', 'status', 'staff_response', 'responded_by_name',
            'responded_at', 'has_unread_response', 'has_staff_response',
            'created_at', 'updated_at',
        ]

    def get_responded_by_name(self, obj):
        if obj.responded_by:
            name = obj.responded_by.get_full_name()
            return name if name.strip() else obj.responded_by.username
        return None

    def get_has_unread_response(self, obj):
        return obj.has_unread_response

    def get_has_staff_response(self, obj):
        return obj.has_staff_response


class SupportRespondSerializer(serializers.Serializer):
    response = serializers.CharField(min_length=5)
    status = serializers.ChoiceField(
        choices=SupportRequest.STATUS_CHOICES,
        required=False,
    )


class StudentRegisterSerializer(serializers.Serializer):
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(min_length=6, write_only=True)
    first_name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    last_name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    student_id = serializers.CharField(max_length=20)
    department = serializers.PrimaryKeyRelatedField(queryset=Department.objects.all())
    course = serializers.PrimaryKeyRelatedField(queryset=Course.objects.all())

    def validate(self, attrs):
        department = attrs['department']
        course = attrs['course']
        if course.department_id != department.id:
            raise serializers.ValidationError(
                {'course': 'Selected course does not belong to the chosen department.'}
            )
        return attrs


class AnnouncementSerializer(serializers.ModelSerializer):
    class Meta:
        model = Announcement
        fields = [
            'id', 'title', 'body', 'priority', 'audience',
            'is_active', 'created_at', 'expires_at',
        ]


class GradeSerializer(serializers.ModelSerializer):
    course_name = serializers.CharField(source='course.name', read_only=True)
    percentage = serializers.FloatField(read_only=True)

    class Meta:
        model = Grade
        fields = [
            'id', 'assessment', 'score', 'max_score', 'percentage',
            'term', 'course', 'course_name', 'recorded_at',
        ]


class AttendanceRecordSerializer(serializers.ModelSerializer):
    course_name = serializers.CharField(source='course.name', read_only=True)

    class Meta:
        model = AttendanceRecord
        fields = [
            'id', 'date', 'status', 'notes', 'course', 'course_name',
        ]
