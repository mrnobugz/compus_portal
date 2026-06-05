from django.apps import AppConfig
from django.contrib.auth.models import User


class ApiConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'api'

    def ready(self):
        self.create_default_admin()

    def create_default_admin(self):
        """Create default admin user if not exists."""
        if not User.objects.filter(username='admin').exists():
            User.objects.create_user(
                username='admin',
                email='admin@campus.edu',
                password='admin123',
                is_staff=True,
                is_superuser=True,
            )
            print('Admin user created: admin / admin123')
