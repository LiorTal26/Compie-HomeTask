import unittest
from uuid import uuid4

from botocore.exceptions import EndpointConnectionError

from app import create_app


class MemoryStore:
    def __init__(self):
        self.items = []
        self.available = True

    def list(self, limit=100):
        if not self.available:
            raise EndpointConnectionError(endpoint_url="http://private-database")
        return self.items[:limit]

    def add(self, text):
        item_id = "1700000000000-" + str(uuid4())
        self.items.insert(0, {"id": item_id, "text": text, "createdAt": "2026-10-25T12:00:00Z"})
        return item_id

    def remove(self, item_id):
        self.items = [item for item in self.items if item["id"] != item_id]


class AppTest(unittest.TestCase):
    def setUp(self):
        self.store = MemoryStore()
        self.app = create_app(self.store, {"welcomeMessage": "Demo", "tableName": "private-table"})
        self.app.config["TESTING"] = True
        self.client = self.app.test_client()

    def test_forms_create_render_escape_and_delete(self):
        text = "<script>alert('demo')</script>"
        self.assertEqual(self.client.post("/items", data={"text": text}).status_code, 303)
        page = self.client.get("/").get_data(as_text=True)
        self.assertIn("&lt;script&gt;", page)
        self.assertNotIn("<script>", page)
        item_id = self.store.items[0]["id"]
        self.assertEqual(self.client.post("/items/" + item_id + "/delete").status_code, 303)
        self.assertEqual(self.store.items, [])
        self.assertEqual(self.client.post("/items/" + item_id + "/delete").status_code, 303)

    def test_invalid_form_does_not_write(self):
        for text in ("", " ", "x" * 201):
            self.assertEqual(self.client.post("/items", data={"text": text}).status_code, 400)
        self.assertEqual(self.client.post("/items", data={"text": "x" * 5000}).status_code, 413)
        self.assertEqual(self.client.post("/items/invalid/delete").status_code, 400)
        self.assertEqual(self.store.items, [])

    def test_database_failure_changes_health_and_page_status(self):
        self.assertEqual(self.client.get("/health").status_code, 200)
        self.store.available = False
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json["database"], "unavailable")
        page = self.client.get("/")
        self.assertEqual(page.status_code, 503)
        self.assertNotIn("private-database", page.get_data(as_text=True))
        self.assertNotIn("private-table", page.get_data(as_text=True))


if __name__ == "__main__":
    unittest.main()
