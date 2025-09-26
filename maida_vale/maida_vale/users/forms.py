from allauth.account.forms import SignupForm
from allauth.socialaccount.forms import SignupForm as SocialSignupForm
from django.contrib.auth import forms as admin_forms
from django.contrib.auth import get_user_model
from django.forms import EmailField
from django.utils.translation import gettext_lazy as _

User = get_user_model()

class UserAdminChangeForm(admin_forms.UserChangeForm):
    """Form for User Change in the Admin Area."""
    class Meta(admin_forms.UserChangeForm.Meta):
        model = User
        fields = "__all__"

class UserAdminCreationForm(admin_forms.UserCreationForm):
    """Form for User Creation in the Admin Area."""
    class Meta(admin_forms.UserCreationForm.Meta):
        model = User
        fields = ("username",)

class UserSignupForm(SignupForm):
    """Form that will be rendered on a user sign up section/screen."""

class UserSocialSignupForm(SocialSignupForm):
    """Form for social account signup."""
