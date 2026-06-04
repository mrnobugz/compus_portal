from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.contrib.auth.models import User
from django.db.models import Q
from django.utils import timezone
from .models import Student, Book, SupportRequest
from .serializers import (
    StudentSerializer,
    BookSerializer,
    BookListSerializer,
    SupportRequestSerializer,
    SupportRespondSerializer,
    UserSerializer,
)
from .utils import validate_file_type, ALLOWED_FILE_TYPES, ALLOWED_IMAGE_TYPES


class StudentViewSet(viewsets.ModelViewSet):
    queryset = Student.objects.select_related('user').order_by('-created_at')
    serializer_class = StudentSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=False, methods=['post', 'put'], permission_classes=[permissions.IsAuthenticated])
    def upload_profile_picture(self, request):
        try:
            student = Student.objects.get(user=request.user)
        except Student.DoesNotExist:
            return Response({'error': 'Student profile not found'}, status=status.HTTP_404_NOT_FOUND)

        file = request.FILES.get('profile_picture')
        if not file:
            return Response({'error': 'No file provided'}, status=status.HTTP_400_BAD_REQUEST)

        if not validate_file_type(file.name, ALLOWED_IMAGE_TYPES):
            return Response(
                {'error': 'Invalid file type. Allowed: jpg, jpeg, png, gif'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        student.profile_picture = file
        student.save(update_fields=['profile_picture', 'updated_at'])
        serializer = self.get_serializer(student)
        return Response(serializer.data)


class BookViewSet(viewsets.ModelViewSet):
    queryset = Book.objects.order_by('-created_at')
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_serializer_class(self):
        if self.action == 'list':
            return BookListSerializer
        return BookSerializer

    def get_queryset(self):
        qs = Book.objects.order_by('-created_at')
        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(
                Q(title__icontains=search) | Q(author__icontains=search)
            )
        return qs

    @action(detail=True, methods=['get'])
    def download(self, request, pk=None):
        book = self.get_object()
        if book.file:
            return Response({
                'download_url': request.build_absolute_uri(book.file.url),
                'filename': book.file.name.split('/')[-1],
                'file_type': book.file.name.rsplit('.', 1)[-1].lower() if '.' in book.file.name else '',
            })
        return Response({'error': 'No file available'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def upload_file(self, request):
        book_id = request.data.get('book_id')
        file = request.FILES.get('file')

        if not book_id or not file:
            return Response({'error': 'book_id and file are required'}, status=status.HTTP_400_BAD_REQUEST)

        if not validate_file_type(file.name, ALLOWED_FILE_TYPES):
            return Response(
                {'error': f'Invalid file type. Allowed: {ALLOWED_FILE_TYPES}'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            book = Book.objects.get(pk=book_id)
            book.file = file
            book.save(update_fields=['file', 'updated_at'])
            return Response({'success': True, 'file_url': book.file.url})
        except Book.DoesNotExist:
            return Response({'error': 'Book not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def upload_cover(self, request):
        book_id = request.data.get('book_id')
        file = request.FILES.get('cover_image')

        if not book_id or not file:
            return Response({'error': 'book_id and cover_image are required'}, status=status.HTTP_400_BAD_REQUEST)

        if not validate_file_type(file.name, ALLOWED_IMAGE_TYPES):
            return Response(
                {'error': 'Invalid image type. Allowed: jpg, jpeg, png, gif'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            book = Book.objects.get(pk=book_id)
            book.cover_image = file
            book.save(update_fields=['cover_image', 'updated_at'])
            return Response({'success': True, 'cover_image_url': book.cover_image.url})
        except Book.DoesNotExist:
            return Response({'error': 'Book not found'}, status=status.HTTP_404_NOT_FOUND)


class SupportRequestViewSet(viewsets.ModelViewSet):
    queryset = SupportRequest.objects.all()
    serializer_class = SupportRequestSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    http_method_names = ['get', 'post', 'head', 'options']

    def get_queryset(self):
        qs = SupportRequest.objects.select_related(
            'student__user', 'responded_by',
        ).order_by('-created_at')
        user = self.request.user
        if not user.is_authenticated:
            return qs.none()
        if user.is_staff:
            return qs
        try:
            student = Student.objects.only('id').get(user=user)
        except Student.DoesNotExist:
            return qs.none()
        return qs.filter(student=student)

    def perform_create(self, serializer):
        try:
            student = Student.objects.only('id').get(user=self.request.user)
        except Student.DoesNotExist:
            from rest_framework.exceptions import ValidationError
            raise ValidationError(
                'Only registered students can submit support requests. '
                'Please contact the administrator if you need help.'
            )
        serializer.save(student=student)

    def create(self, request, *args, **kwargs):
        if not request.user.is_authenticated:
            return Response({'detail': 'Authentication required.'}, status=401)
        return super().create(request, *args, **kwargs)

    @action(detail=True, methods=['post'])
    def update_status(self, request, pk=None):
        if not request.user.is_staff:
            return Response({'error': 'Admin only'}, status=status.HTTP_403_FORBIDDEN)

        support_request = self.get_object()
        new_status = request.data.get('status')
        if new_status not in dict(SupportRequest.STATUS_CHOICES):
            return Response({'error': 'Invalid status'}, status=status.HTTP_400_BAD_REQUEST)
        support_request.status = new_status
        support_request.save(update_fields=['status', 'updated_at'])
        serializer = self.get_serializer(support_request)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def respond(self, request, pk=None):
        """Staff posts a solution/update visible to the student in the app."""
        if not request.user.is_staff:
            return Response({'error': 'Staff only'}, status=status.HTTP_403_FORBIDDEN)

        support_request = self.get_object()
        serializer = SupportRespondSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        support_request.staff_response = serializer.validated_data['response']
        support_request.responded_by = request.user
        support_request.responded_at = timezone.now()
        support_request.response_read_at = None

        new_status = serializer.validated_data.get('status')
        if new_status:
            support_request.status = new_status
        elif support_request.status == 'pending':
            support_request.status = 'in_progress'

        support_request.save()
        out = SupportRequestSerializer(support_request, context={'request': request})
        return Response(out.data)

    @action(detail=True, methods=['post'], url_path='mark-read')
    def mark_read(self, request, pk=None):
        """Student marks staff response as read."""
        support_request = self.get_object()
        user = request.user
        if not user.is_staff:
            try:
                student = Student.objects.get(user=user)
            except Student.DoesNotExist:
                return Response({'error': 'Not allowed'}, status=status.HTTP_403_FORBIDDEN)
            if support_request.student_id != student.id:
                return Response({'error': 'Not allowed'}, status=status.HTTP_403_FORBIDDEN)

        if support_request.has_staff_response:
            support_request.response_read_at = timezone.now()
            support_request.save(update_fields=['response_read_at'])

        out = SupportRequestSerializer(support_request, context={'request': request})
        return Response(out.data)


class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.order_by('id')
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAdminUser]

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def me(self, request):
        user = request.user
        data = {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'first_name': user.first_name,
            'last_name': user.last_name,
        }
        student = Student.objects.filter(user=user).select_related(
            'department', 'course'
        ).prefetch_related('study_groups').first()
        if student:
            data['student_id'] = student.student_id
            data['department_id'] = student.department_id
            data['department'] = student.department.name
            if student.profile_picture:
                data['profile_picture_url'] = request.build_absolute_uri(
                    student.profile_picture.url
                )
            if student.course:
                data['course_id'] = student.course_id
                data['course'] = student.course.name
                data['course_code'] = student.course.code
            data['groups'] = list(
                student.study_groups.values('id', 'name')
            )
        from .models import Lecturer
        data['is_lecturer'] = Lecturer.objects.filter(user=user).exists()
        data['is_staff'] = user.is_staff
        return Response(data)

    @action(detail=False, methods=['post'], url_path='change-password',
            permission_classes=[permissions.IsAuthenticated])
    def change_password(self, request):
        current = request.data.get('current_password', '')
        new_password = request.data.get('new_password', '')
        if not current or not new_password:
            return Response(
                {'detail': 'Current and new password are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if len(new_password) < 6:
            return Response(
                {'detail': 'New password must be at least 6 characters.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not request.user.check_password(current):
            return Response(
                {'detail': 'Current password is incorrect.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        request.user.set_password(new_password)
        request.user.save(update_fields=['password'])
        return Response({'detail': 'Password updated successfully.'})

    @action(detail=False, methods=['patch'], url_path='update-profile',
            permission_classes=[permissions.IsAuthenticated])
    def update_profile(self, request):
        user = request.user
        allowed = {'first_name', 'last_name', 'email'}
        for field in allowed:
            if field in request.data:
                setattr(user, field, request.data[field])
        if 'email' in request.data:
            email = request.data['email'].strip()
            if User.objects.filter(email__iexact=email).exclude(pk=user.pk).exists():
                return Response(
                    {'detail': 'This email is already in use.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            user.email = email
        user.save()
        return Response({
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'first_name': user.first_name,
            'last_name': user.last_name,
        })
