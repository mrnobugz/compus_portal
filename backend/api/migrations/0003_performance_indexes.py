from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0002_remove_book_file_url_book_file_and_more'),
    ]

    operations = [
        migrations.AddIndex(
            model_name='student',
            index=models.Index(fields=['department'], name='api_student_departm_8a1f2c_idx'),
        ),
        migrations.AddIndex(
            model_name='student',
            index=models.Index(fields=['created_at'], name='api_student_created_4b2e1a_idx'),
        ),
        migrations.AddIndex(
            model_name='book',
            index=models.Index(fields=['-created_at'], name='api_book_created_9c3d4e_idx'),
        ),
        migrations.AddIndex(
            model_name='book',
            index=models.Index(fields=['author'], name='api_book_author_2f5a6b_idx'),
        ),
        migrations.AddIndex(
            model_name='supportrequest',
            index=models.Index(fields=['status'], name='api_support_status_7e8f9a_idx'),
        ),
        migrations.AddIndex(
            model_name='supportrequest',
            index=models.Index(fields=['-created_at'], name='api_support_created_1a2b3c_idx'),
        ),
        migrations.AddIndex(
            model_name='supportrequest',
            index=models.Index(fields=['student', 'status'], name='api_support_student_4d5e6f_idx'),
        ),
    ]
