import os
from pathlib import Path

from django.core.exceptions import ImproperlyConfigured
from google.cloud import secretmanager

BASE_DIR = Path(__file__).resolve().parent.parent

# Initialize Secret Manager client once for reuse
_sm_client = secretmanager.SecretManagerServiceClient()


def get_secret(project_id: str, secret_id: str) -> str:
    """Fetch secret from GCP Secret Manager with error handling."""
    name = f"projects/{project_id}/secrets/{secret_id}/versions/latest"
    try:
        response = _sm_client.access_secret_version(request={"name": name})
        return response.payload.data.decode("UTF-8").strip()
    except Exception as e:
        raise ImproperlyConfigured(f"Could not retrieve secret {secret_id} from GCP: {e}")


if "GCP_PROJECT_ID" not in os.environ:
    raise ImproperlyConfigured("GCP_PROJECT_ID environment variable is required.")

_PROJECT_ID = os.environ["GCP_PROJECT_ID"]

SECRET_KEY = get_secret(_PROJECT_ID, "talana-django-secret-key")
_DB_PASSWORD = get_secret(_PROJECT_ID, "talana-db-password")
_DB_HOST = get_secret(_PROJECT_ID, "talana-db-host")
_DB_NAME = get_secret(_PROJECT_ID, "talana-db-name")
_DB_USER = get_secret(_PROJECT_ID, "talana-db-user")

DEBUG = False

# Robust parsing of comma-separated hosts with whitespace stripping
ALLOWED_HOSTS = [
    host.strip()
    for host in os.environ.get("DJANGO_ALLOWED_HOSTS", "").split(",")
    if host.strip()
]

INSTALLED_APPS = [
    "django.contrib.contenttypes",
    "django.contrib.auth",
    "health.apps.HealthConfig",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.middleware.gzip.GZipMiddleware",  # Performance: Compress static files
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "talana.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "talana.wsgi.application"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": _DB_NAME,
        "USER": _DB_USER,
        "PASSWORD": _DB_PASSWORD,
        "HOST": _DB_HOST,
        "PORT": "5432",
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# Production Security Headers
CSRF_COOKIE_SECURE = True
SESSION_COOKIE_SECURE = True
SECURE_SSL_REDIRECT = os.environ.get("DJANGO_SECURE_SSL_REDIRECT", "True") == "True"
SECURE_HSTS_SECONDS = 31536000  # 1 year
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True
