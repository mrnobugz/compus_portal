from rest_framework import permissions
from .models import Lecturer


class IsLecturerOrStaff(permissions.BasePermission):
    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False
        if request.user.is_staff:
            return True
        return Lecturer.objects.filter(user=request.user).exists()
