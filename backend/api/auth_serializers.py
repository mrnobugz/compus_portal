from django.contrib.auth.models import User
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.views import TokenObtainPairView


class EmailOrUsernameTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Accept username or email in the username field."""

    def validate(self, attrs):
        login = (attrs.get('username') or '').strip()
        if not login:
            raise serializers.ValidationError({'username': 'This field is required.'})

        by_username = User.objects.filter(username__iexact=login).first()
        if by_username is not None:
            attrs['username'] = by_username.username
        elif '@' in login:
            matches = User.objects.filter(email__iexact=login)
            count = matches.count()
            if count == 1:
                attrs['username'] = matches.first().username
            elif count > 1:
                raise serializers.ValidationError(
                    {
                        'username': (
                            'Multiple accounts share this email. '
                            'Please log in with your username instead.'
                        )
                    }
                )
        return super().validate(attrs)


class EmailOrUsernameTokenObtainPairView(TokenObtainPairView):
    serializer_class = EmailOrUsernameTokenObtainPairSerializer
