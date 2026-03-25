from django.test import TestCase, Client


class HealthzViewTest(TestCase):
    def test_healthz_returns_200(self):
        client = Client()
        response = client.get("/healthz/")
        self.assertEqual(response.status_code, 200)
