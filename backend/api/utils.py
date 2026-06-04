ALLOWED_FILE_TYPES = ['pdf', 'ppt', 'pptx', 'doc', 'docx', 'txt']
ALLOWED_IMAGE_TYPES = ['jpg', 'jpeg', 'png', 'gif']


def validate_file_type(filename, allowed_types):
    ext = filename.rsplit('.', 1)[-1].lower()
    return ext in allowed_types
