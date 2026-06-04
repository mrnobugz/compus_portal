from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import (
    Department,
    Course,
    Student,
    StudyGroup,
    Note,
    Assignment,
    Lecturer,
)
from .serializers import (
    DepartmentSerializer,
    CourseSerializer,
    StudyGroupSerializer,
    NoteListSerializer,
    NoteSerializer,
    AssignmentListSerializer,
    AssignmentSerializer,
    AssignmentCreateSerializer,
)
from .permissions import IsLecturerOrStaff
from .utils import validate_file_type, ALLOWED_FILE_TYPES


def _get_student(user):
    try:
        return Student.objects.select_related('department', 'course').get(user=user)
    except Student.DoesNotExist:
        return None


def _student_group_ids(student):
    return list(student.study_groups.values_list('id', flat=True))


class DepartmentViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Department.objects.all()
    serializer_class = DepartmentSerializer
    permission_classes = [permissions.AllowAny]


class CourseViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Course.objects.select_related('department')
    serializer_class = CourseSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        qs = super().get_queryset()
        department_id = self.request.query_params.get('department')
        if department_id:
            qs = qs.filter(department_id=department_id)
        return qs


class StudyGroupViewSet(viewsets.ModelViewSet):
    queryset = StudyGroup.objects.select_related('department', 'course', 'lecturer')
    serializer_class = StudyGroupSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = super().get_queryset()
        if user.is_staff:
            return qs
        if Lecturer.objects.filter(user=user).exists():
            return qs.filter(lecturer=user)
        student = _get_student(user)
        if student:
            return qs.filter(students=student)
        return qs.none()

    def get_permissions(self):
        if self.action in ('create', 'update', 'partial_update', 'destroy'):
            return [permissions.IsAdminUser()]
        return super().get_permissions()


class NoteViewSet(viewsets.ModelViewSet):
    queryset = Note.objects.prefetch_related('groups').order_by('-created_at')
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.action == 'list':
            return NoteListSerializer
        return NoteSerializer

    def get_queryset(self):
        user = self.request.user
        qs = super().get_queryset()
        if user.is_staff:
            return qs
        student = _get_student(user)
        if not student:
            return qs.none()
        group_ids = _student_group_ids(student)
        if not group_ids:
            return qs.none()
        return qs.filter(groups__id__in=group_ids).distinct()

    def get_permissions(self):
        if self.action in ('create', 'update', 'partial_update', 'destroy'):
            return [IsLecturerOrStaff()]
        return [permissions.IsAuthenticated()]

    def perform_create(self, serializer):
        note = serializer.save(uploaded_by=self.request.user)
        group_ids = self.request.data.getlist('group_ids') or self.request.data.get('group_ids')
        if group_ids:
            if isinstance(group_ids, str):
                group_ids = [int(x) for x in group_ids.split(',') if x.strip()]
            note.groups.set(group_ids)

    @action(detail=True, methods=['get'])
    def download(self, request, pk=None):
        note = self.get_object()
        if not note.file:
            return Response({'error': 'No file available'}, status=status.HTTP_404_NOT_FOUND)
        return Response({
            'download_url': request.build_absolute_uri(note.file.url),
            'filename': note.file.name.split('/')[-1],
            'file_type': note.file_extension,
        })

    @action(detail=True, methods=['get'])
    def read(self, request, pk=None):
        """Return metadata for in-app reading."""
        note = self.get_object()
        if not note.file:
            return Response({'error': 'No file available'}, status=status.HTTP_404_NOT_FOUND)
        return Response({
            'id': note.id,
            'title': note.title,
            'file_url': request.build_absolute_uri(note.file.url),
            'file_type': note.file_extension,
            'can_read_in_app': note.file_extension in ('pdf', 'txt'),
        })


class AssignmentViewSet(viewsets.ModelViewSet):
    queryset = Assignment.objects.select_related('lecturer').prefetch_related('groups')
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.action == 'create':
            return AssignmentCreateSerializer
        if self.action == 'list':
            return AssignmentListSerializer
        return AssignmentSerializer

    def get_queryset(self):
        user = self.request.user
        qs = super().get_queryset()
        if user.is_staff:
            return qs
        if Lecturer.objects.filter(user=user).exists():
            return qs.filter(lecturer=user)
        student = _get_student(user)
        if not student:
            return qs.none()
        group_ids = _student_group_ids(student)
        if not group_ids:
            return qs.none()
        return qs.filter(groups__id__in=group_ids).distinct()

    def get_permissions(self):
        if self.action == 'create':
            return [IsLecturerOrStaff()]
        if self.action in ('update', 'partial_update', 'destroy'):
            return [IsLecturerOrStaff()]
        return [permissions.IsAuthenticated()]

    def create(self, request, *args, **kwargs):
        group_ids = request.data.getlist('group_ids')
        if not group_ids and request.data.get('group_ids'):
            raw = request.data.get('group_ids')
            if isinstance(raw, list):
                group_ids = raw
            else:
                group_ids = [x.strip() for x in str(raw).split(',') if x.strip()]

        serializer = AssignmentCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        file = request.FILES.get('file')
        if not file:
            return Response({'error': 'file is required'}, status=status.HTTP_400_BAD_REQUEST)
        if not validate_file_type(file.name, ALLOWED_FILE_TYPES):
            return Response(
                {'error': f'Invalid file type. Allowed: {ALLOWED_FILE_TYPES}'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not group_ids:
            return Response({'error': 'At least one group_ids required'}, status=status.HTTP_400_BAD_REQUEST)

        user = request.user
        if not user.is_staff:
            allowed = StudyGroup.objects.filter(lecturer=user, id__in=group_ids).count()
            if allowed != len(set(int(g) for g in group_ids)):
                return Response(
                    {'error': 'You can only assign to groups you teach'},
                    status=status.HTTP_403_FORBIDDEN,
                )

        assignment = Assignment.objects.create(
            title=serializer.validated_data['title'],
            description=serializer.validated_data.get('description', ''),
            file=file,
            due_date=serializer.validated_data.get('due_date'),
            lecturer=user,
        )
        assignment.groups.set(group_ids)
        out = AssignmentSerializer(assignment, context={'request': request})
        return Response(out.data, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['get'], permission_classes=[IsLecturerOrStaff])
    def my_groups(self, request):
        """Groups the lecturer can post assignments to."""
        user = request.user
        if user.is_staff:
            groups = StudyGroup.objects.select_related('department', 'course')
        else:
            groups = StudyGroup.objects.filter(lecturer=user).select_related('department', 'course')
        serializer = StudyGroupSerializer(groups, many=True, context={'request': request})
        return Response(serializer.data)

    @action(detail=True, methods=['get'])
    def download(self, request, pk=None):
        assignment = self.get_object()
        return Response({
            'download_url': request.build_absolute_uri(assignment.file.url),
            'filename': assignment.file.name.split('/')[-1],
        })
