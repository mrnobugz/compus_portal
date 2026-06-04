from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('api', '0005_announcements_grades_attendance'),
    ]

    operations = [
        migrations.AddField(
            model_name='supportrequest',
            name='staff_response',
            field=models.TextField(blank=True, default=''),
        ),
        migrations.AddField(
            model_name='supportrequest',
            name='responded_by',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='support_responses',
                to=settings.AUTH_USER_MODEL,
            ),
        ),
        migrations.AddField(
            model_name='supportrequest',
            name='responded_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='supportrequest',
            name='response_read_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
