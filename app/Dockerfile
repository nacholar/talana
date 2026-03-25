# Stage 1: Builder — install deps and collect static files
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN DJANGO_SETTINGS_MODULE=talana.settings_test python manage.py collectstatic --noinput

# Stage 2: Final — minimal production image
FROM python:3.12-slim
RUN groupadd --gid 1000 appuser \
    && useradd --uid 1000 --gid 1000 --no-create-home appuser
WORKDIR /app
COPY --from=builder --chown=appuser:appuser /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder --chown=appuser:appuser /usr/local/bin/gunicorn /usr/local/bin/gunicorn
COPY --from=builder --chown=appuser:appuser /app .
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
USER 1000
EXPOSE 8000
CMD ["gunicorn", "talana.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "2"]
