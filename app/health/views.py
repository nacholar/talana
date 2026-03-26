from django.db import connection
from django.http import HttpResponse


def healthz(request):
    """
    Health check endpoint that verifies the database connection.
    Returns 200 OK if the database is reachable, 503 Service Unavailable otherwise.
    """
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
    except Exception:
        return HttpResponse("Database connection failed", status=503)

    return HttpResponse("OK", status=200)
