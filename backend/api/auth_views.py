from django.contrib.auth.models import User
from django.db import transaction
from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from .models import Course, Department, Student
from .group_utils import sync_student_to_groups
from .serializers import StudentRegisterSerializer


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def register_student(request):
    serializer = StudentRegisterSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    data = serializer.validated_data
    username = data['username']
    email = data['email']
    student_id = data['student_id']
    department = data['department']
    course = data['course']

    if User.objects.filter(username=username).exists():
        return Response({'username': ['This username is already taken.']}, status=400)
    if User.objects.filter(email=email).exists():
        return Response({'email': ['This email is already registered.']}, status=400)
    if Student.objects.filter(student_id=student_id).exists():
        return Response({'student_id': ['This student ID is already registered.']}, status=400)

    with transaction.atomic():
        user = User.objects.create_user(
            username=username,
            email=email,
            password=data['password'],
            first_name=data.get('first_name', ''),
            last_name=data.get('last_name', ''),
        )
        student = Student.objects.create(
            user=user,
            student_id=student_id,
            department=department,
            course=course,
        )
        sync_student_to_groups(student)

    return Response(
        {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'student_id': student.student_id,
            'department': department.name,
            'course': course.name,
        },
        status=status.HTTP_201_CREATED,
    )
