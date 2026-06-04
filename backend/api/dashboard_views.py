from django.contrib.auth.decorators import user_passes_test
from django.shortcuts import redirect

from .dashboard_context import build_dashboard_context


def is_admin(user):
    return user.is_staff


@user_passes_test(is_admin)
def admin_dashboard(request):
    """Legacy URL — redirects to the styled admin analytics home."""
    return redirect('admin:index')
