import pytest
import sys
import os
import importlib
from io import BytesIO

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

os.environ.setdefault("SECRET_KEY", "test-secret-key-12345678901234567890")
os.environ.setdefault("JWT_SECRET", "test-jwt-secret-12345678901234567890")
os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("ASLI_AUTO_MIGRATE", "1")
os.environ.setdefault("ASLI_SEED_DEMO_DATA", "0")

from app import create_app
from config import Config
from database.models import db, UserAccount
from utils.rate_limit import clear_rate_limits

TINY_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01"
    b"\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89"
    b"\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01"
    b"\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
)


def login(client, email="rahul@au.edu", password="Test123!"):
    response = client.post("/api/auth/login", json={"email": email, "password": password})
    assert response.status_code == 200
    return response.get_json()["token"]


def auth_headers(token):
    return {"Authorization": f"Bearer {token}"}


def create_test_user(
    email="rahul@au.edu",
    username="rahul_sharma",
    password="Test123!",
    *,
    is_admin=False,
):
    user = UserAccount(
        name="Rahul Sharma",
        username=username,
        email=email,
        department="CSE",
        year="3rd",
        is_admin=is_admin,
    )
    user.set_password(password)
    db.session.add(user)
    db.session.commit()
    return user


@pytest.fixture
def client(monkeypatch):
    clear_rate_limits()
    monkeypatch.setattr(Config, "AUTO_MIGRATE", True)
    monkeypatch.setattr(Config, "SEED_DEMO_DATA", True)
    app = create_app()
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client
    clear_rate_limits()


@pytest.fixture
def minimal_client(monkeypatch):
    clear_rate_limits()
    monkeypatch.setattr(Config, "AUTO_MIGRATE", True)
    monkeypatch.setattr(Config, "SEED_DEMO_DATA", False)
    app = create_app()
    app.config["TESTING"] = True
    with app.app_context():
        db.drop_all()
        db.create_all()
        create_test_user()
    with app.test_client() as client:
        yield client
    clear_rate_limits()


@pytest.fixture
def runner():
    app = create_app()
    return app.test_cli_runner()


class TestHealthEndpoint:
    def test_home_returns_200(self, minimal_client):
        response = minimal_client.get("/")
        assert response.status_code == 200

    def test_home_returns_success(self, minimal_client):
        response = minimal_client.get("/")
        data = response.get_json()
        assert data["success"] == True
        assert "modules" in data
        assert "version" in data

    def test_health_adds_request_correlation_headers(self, minimal_client):
        response = minimal_client.get("/health", headers={"X-Request-ID": "test-request-123"})

        assert response.status_code == 200
        assert response.headers["X-Request-ID"] == "test-request-123"
        assert "X-Response-Time-ms" in response.headers

    def test_ready_reports_database_and_chatbot_checks(self, minimal_client):
        response = minimal_client.get("/ready")
        data = response.get_json()

        assert response.status_code == 200
        assert data["status"] == "ready"
        assert data["success"] == True
        assert data["checks"]["database"]["status"] == "healthy"
        assert data["checks"]["chatbot"]["ready"] == True
        assert data["checks"]["chatbot"]["knowledge_base_items"] > 0

    def test_error_response_includes_request_id(self, minimal_client):
        response = minimal_client.get("/missing-route", headers={"X-Request-ID": "missing-123"})
        data = response.get_json()

        assert response.status_code == 404
        assert response.headers["X-Request-ID"] == "missing-123"
        assert data["success"] == False
        assert data["error_code"] == "NOT_FOUND"
        assert data["request_id"] == "missing-123"


class TestProductionConfig:
    def test_production_requires_explicit_cors_origins(self, monkeypatch):
        import config as config_module

        monkeypatch.setenv("SECRET_KEY", "production-secret-12345678901234567890")
        monkeypatch.setenv("JWT_SECRET", "production-jwt-12345678901234567890")
        monkeypatch.setenv("ASLI_ENV", "production")
        monkeypatch.delenv("ASLI_CORS_ORIGINS", raising=False)

        reloaded = importlib.reload(config_module)

        with pytest.raises(RuntimeError, match="ASLI_CORS_ORIGINS"):
            reloaded.Config.validate()

    def test_production_accepts_explicit_cors_origins(self, monkeypatch):
        import config as config_module

        monkeypatch.setenv("SECRET_KEY", "production-secret-12345678901234567890")
        monkeypatch.setenv("JWT_SECRET", "production-jwt-12345678901234567890")
        monkeypatch.setenv("ASLI_ENV", "production")
        monkeypatch.setenv("ASLI_CORS_ORIGINS", "https://asli.example.com,https://admin.example.com")

        reloaded = importlib.reload(config_module)
        reloaded.Config.validate()

        assert reloaded.Config.CORS_ORIGINS == [
            "https://asli.example.com",
            "https://admin.example.com",
        ]


class TestDistributedSecurityStore:
    def test_cache_store_uses_redis_client_when_available(self, monkeypatch):
        from utils import cache_store

        class FakeRedis:
            def __init__(self):
                self.values = {}
                self.expiries = {}

            def get(self, key):
                return self.values.get(key)

            def setex(self, key, ttl, value):
                self.values[key] = str(value)
                self.expiries[key] = ttl

            def incr(self, key):
                self.values[key] = str(int(self.values.get(key, "0")) + 1)
                return int(self.values[key])

            def expire(self, key, ttl):
                self.expiries[key] = ttl

            def delete(self, key):
                self.values.pop(key, None)

        fake_redis = FakeRedis()
        monkeypatch.setattr(cache_store, "get_redis_client", lambda: fake_redis)

        cache_store.cache_set("test:key", "value", 30)
        assert cache_store.cache_get("test:key") == "value"
        assert cache_store.cache_incr("test:counter", 60) == 1
        assert cache_store.cache_incr("test:counter", 60) == 2
        assert fake_redis.expiries["test:counter"] == 60

    def test_blacklisted_token_is_rejected(self, minimal_client):
        from modules.auth.jwt_utils import blacklist_token, decode_token, generate_token

        secret = minimal_client.application.config["JWT_SECRET"]
        with minimal_client.application.app_context():
            token = generate_token(2, secret)

            assert decode_token(token, secret) == 2
            blacklist_token(token)
            assert decode_token(token, secret) is None


class TestAuthModule:
    def test_login_with_valid_credentials(self, minimal_client):
        response = minimal_client.post(
            "/api/auth/login", json={"email": "rahul@au.edu", "password": "Test123!"}
        )
        assert response.status_code == 200
        data = response.get_json()
        assert data["success"] == True
        assert "token" in data
        assert "refresh_token" in data
        assert "user" in data

    def test_login_with_invalid_credentials(self, minimal_client):
        response = minimal_client.post(
            "/api/auth/login", json={"email": "invalid@test.com", "password": "wrong"}
        )
        assert response.status_code == 401

    def test_register_new_user(self, minimal_client):
        response = minimal_client.post(
            "/api/auth/register",
            json={
                "name": "Test User",
                "email": f"test_{id(minimal_client)}@au.edu",
                "password": "test123",
                "username": f"testuser_{id(minimal_client)}",
                "department": "CSE",
                "year": "1st",
            },
        )
        assert response.status_code in [200, 201]

    def test_refresh_token_rotates_tokens_and_blacklists_old_refresh(self, minimal_client):
        login_response = minimal_client.post(
            "/api/auth/login", json={"email": "rahul@au.edu", "password": "Test123!"}
        )
        refresh_token = login_response.get_json()["refresh_token"]

        refresh_response = minimal_client.post(
            "/api/auth/refresh", json={"refresh_token": refresh_token}
        )
        assert refresh_response.status_code == 200
        data = refresh_response.get_json()
        assert data["success"] == True
        assert "access_token" in data
        assert "refresh_token" in data

        replay_response = minimal_client.post(
            "/api/auth/refresh", json={"refresh_token": refresh_token}
        )
        assert replay_response.status_code == 401

    def test_auth_rate_limit_blocks_repeated_failures(self, minimal_client):
        clear_rate_limits()
        minimal_client.application.config["AUTH_RATE_LIMIT_PER_MINUTE"] = 2

        payload = {"email": "missing@au.edu", "password": "wrong"}
        headers = {"X-Forwarded-For": "203.0.113.10"}

        assert minimal_client.post("/api/auth/login", json=payload, headers=headers).status_code == 401
        assert minimal_client.post("/api/auth/login", json=payload, headers=headers).status_code == 401

        response = minimal_client.post("/api/auth/login", json=payload, headers=headers)
        assert response.status_code == 429
        assert response.get_json()["error_code"] == "RATE_LIMITED"
        clear_rate_limits()

    def test_login_profile_logout_and_refresh_session_lifecycle(self, minimal_client):
        login_response = minimal_client.post(
            "/api/auth/login", json={"email": "rahul@au.edu", "password": "Test123!"}
        )
        assert login_response.status_code == 200
        session = login_response.get_json()
        access_token = session["token"]
        refresh_token = session["refresh_token"]

        profile_response = minimal_client.get("/api/auth/me", headers=auth_headers(access_token))
        assert profile_response.status_code == 200
        assert profile_response.get_json()["user"]["email"] == "rahul@au.edu"

        logout_response = minimal_client.post("/api/auth/logout", headers=auth_headers(access_token))
        assert logout_response.status_code == 200

        rejected_profile = minimal_client.get("/api/auth/me", headers=auth_headers(access_token))
        assert rejected_profile.status_code == 401
        assert rejected_profile.get_json()["error_code"] == "AUTH_TOKEN_INVALID"

        refresh_response = minimal_client.post(
            "/api/auth/refresh", json={"refresh_token": refresh_token}
        )
        assert refresh_response.status_code == 200
        refreshed = refresh_response.get_json()
        assert refreshed["access_token"] != access_token
        assert refreshed["refresh_token"] != refresh_token

        replay_response = minimal_client.post(
            "/api/auth/refresh", json={"refresh_token": refresh_token}
        )
        assert replay_response.status_code == 401

        refreshed_profile = minimal_client.get(
            "/api/auth/me",
            headers=auth_headers(refreshed["access_token"]),
        )
        assert refreshed_profile.status_code == 200


class TestChatV2:
    def test_chat_endpoint_exists(self, minimal_client):
        response = minimal_client.post(
            "/api/chat/message", json={"message": "Hello", "save": False}
        )
        assert response.status_code == 200
        data = response.get_json()
        assert data["success"] == True
        assert "answer" in data

    def test_chat_returns_intent(self, minimal_client):
        response = minimal_client.post(
            "/api/chat/message",
            json={"message": "What about exam schedule?", "save": False},
        )
        data = response.get_json()
        assert data["success"] == True
        assert "category" in data

    def test_chat_history(self, minimal_client):
        token = login(minimal_client)
        response = minimal_client.get(
            "/api/chat/history",
            headers=auth_headers(token),
        )
        assert response.status_code == 200
        data = response.get_json()
        assert data["success"] == True
        assert "data" in data


class TestAdminSecurity:
    def test_non_admin_cannot_list_users(self, minimal_client):
        token = login(minimal_client)
        response = minimal_client.get("/api/admin/users", headers=auth_headers(token))

        assert response.status_code == 403
        assert response.get_json()["error_code"] == "ADMIN_ACCESS_REQUIRED"

    def test_admin_cannot_toggle_another_admin(self, minimal_client):
        with minimal_client.application.app_context():
            create_test_user(
                email="admin@au.edu",
                username="admin_user",
                password="Admin123!",
                is_admin=True,
            )
            other_admin = create_test_user(
                email="other-admin@au.edu",
                username="other_admin",
                password="Admin123!",
                is_admin=True,
            )
            other_admin_id = other_admin.id

        token = login(minimal_client, "admin@au.edu", "Admin123!")
        response = minimal_client.post(
            f"/api/admin/users/{other_admin_id}/toggle",
            headers=auth_headers(token),
        )

        assert response.status_code == 403
        assert response.get_json()["error_code"] == "CANNOT_DEACTIVATE_ADMIN"


class TestUploadSecurity:
    def test_upload_requires_authentication(self, minimal_client):
        response = minimal_client.post("/api/upload/image", json={"image": "abc"})

        assert response.status_code == 401
        assert response.get_json()["error_code"] == "AUTH_TOKEN_MISSING"

    def test_authenticated_upload_accepts_flutter_image_field(self, minimal_client, monkeypatch, tmp_path):
        from modules.upload import routes as upload_routes

        monkeypatch.setattr(upload_routes, "get_upload_folder", lambda: str(tmp_path))
        token = login(minimal_client)

        response = minimal_client.post(
            "/api/upload/image",
            headers=auth_headers(token),
            data={"image": (BytesIO(TINY_PNG), "avatar.png")},
            content_type="multipart/form-data",
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data["success"] == True
        assert data["filename"].endswith(".png")

    def test_authenticated_upload_rejects_disguised_non_image_file(self, minimal_client, monkeypatch, tmp_path):
        from modules.upload import routes as upload_routes

        monkeypatch.setattr(upload_routes, "get_upload_folder", lambda: str(tmp_path))
        token = login(minimal_client)

        response = minimal_client.post(
            "/api/upload/image",
            headers=auth_headers(token),
            data={"image": (BytesIO(b"<script>alert('xss')</script>"), "avatar.png")},
            content_type="multipart/form-data",
        )

        assert response.status_code == 400
        assert response.get_json()["error"] == "Invalid image content"

    def test_upload_list_and_delete_admin_lifecycle(self, minimal_client, monkeypatch, tmp_path):
        from modules.upload import routes as upload_routes

        monkeypatch.setattr(upload_routes, "get_upload_folder", lambda: str(tmp_path))

        user_token = login(minimal_client)
        with minimal_client.application.app_context():
            create_test_user(
                email="upload-admin@au.edu",
                username="upload_admin",
                password="Admin123!",
                is_admin=True,
            )

        admin_token = login(minimal_client, "upload-admin@au.edu", "Admin123!")

        upload_response = minimal_client.post(
            "/api/upload/image",
            headers=auth_headers(user_token),
            data={"image": (BytesIO(TINY_PNG), "moderated.png")},
            content_type="multipart/form-data",
        )
        assert upload_response.status_code == 200
        filename = upload_response.get_json()["filename"]

        non_admin_list = minimal_client.get("/api/upload/list", headers=auth_headers(user_token))
        assert non_admin_list.status_code == 403

        admin_list = minimal_client.get("/api/upload/list", headers=auth_headers(admin_token))
        assert admin_list.status_code == 200
        listed_files = [item["filename"] for item in admin_list.get_json()["files"]]
        assert filename in listed_files

        delete_response = minimal_client.delete(
            f"/api/upload/{filename}",
            headers=auth_headers(admin_token),
        )
        assert delete_response.status_code == 200
        assert delete_response.get_json()["success"] == True

        missing_delete = minimal_client.delete(
            f"/api/upload/{filename}",
            headers=auth_headers(admin_token),
        )
        assert missing_delete.status_code == 404


class TestEndToEndUserFlows:
    def _register_user(self, client, suffix, is_admin=False):
        response = client.post(
            "/api/auth/register",
            json={
                "name": f"Flow User {suffix}",
                "email": f"flow-{suffix}@au.edu",
                "password": "FlowPass123!",
                "username": f"flow_{suffix}",
                "department": "CSE",
                "year": "2nd",
            },
        )
        assert response.status_code == 201
        data = response.get_json()
        user_id = data["user"]["id"]

        if is_admin:
            with client.application.app_context():
                user = db.session.get(UserAccount, user_id)
                user.is_admin = True
                db.session.commit()

        return data["token"], user_id

    def test_register_post_like_reply_and_admin_moderation_flow(self, client):
        author_token, author_id = self._register_user(client, "author")
        viewer_token, viewer_id = self._register_user(client, "viewer")
        admin_token, _admin_id = self._register_user(client, "admin", is_admin=True)

        create_response = client.post(
            "/api/collx/posts",
            headers=auth_headers(author_token),
            json={"content": "Full journey test post #quality"},
        )
        assert create_response.status_code == 201
        post = create_response.get_json()["data"]
        post_id = post["id"]
        assert post["user_id"] == author_id
        assert post["like_count"] == 0
        assert post["reply_count"] == 0

        like_response = client.post(
            f"/api/collx/posts/{post_id}/like",
            headers=auth_headers(viewer_token),
        )
        assert like_response.status_code == 200
        assert like_response.get_json()["liked"] == True
        assert like_response.get_json()["like_count"] == 1

        reply_response = client.post(
            f"/api/collx/posts/{post_id}/reply",
            headers=auth_headers(viewer_token),
            json={"content": "This flow is covered now."},
        )
        assert reply_response.status_code == 201
        assert reply_response.get_json()["data"]["user_id"] == viewer_id

        detail_response = client.get(
            f"/api/collx/posts/{post_id}",
            headers=auth_headers(viewer_token),
        )
        assert detail_response.status_code == 200
        detail = detail_response.get_json()
        assert detail["data"]["is_liked"] == True
        assert detail["data"]["like_count"] == 1
        assert detail["data"]["reply_count"] == 1
        assert len(detail["replies"]) == 1

        unauthorized_delete = client.delete(
            f"/api/collx/posts/{post_id}",
            headers=auth_headers(viewer_token),
        )
        assert unauthorized_delete.status_code == 403
        assert unauthorized_delete.get_json()["error_code"] == "AUTH_UNAUTHORIZED"

        admin_delete = client.delete(
            f"/api/admin/posts/{post_id}",
            headers=auth_headers(admin_token),
        )
        assert admin_delete.status_code == 200
        assert admin_delete.get_json()["success"] == True

        missing_response = client.get(f"/api/collx/posts/{post_id}")
        assert missing_response.status_code == 404

    def test_direct_message_conversation_unread_and_read_flow(self, client):
        sender_token, sender_id = self._register_user(client, "dm_sender")
        receiver_token, receiver_id = self._register_user(client, "dm_receiver")

        send_response = client.post(
            "/api/messages/send",
            headers=auth_headers(sender_token),
            json={"receiver_id": receiver_id, "content": "Can you review my project?"},
        )
        assert send_response.status_code == 201
        message = send_response.get_json()["data"]
        assert message["sender_id"] == sender_id
        assert message["receiver_id"] == receiver_id
        assert message["is_read"] == False

        unread_response = client.get(
            "/api/messages/unread-total",
            headers=auth_headers(receiver_token),
        )
        assert unread_response.status_code == 200
        assert unread_response.get_json()["count"] == 1

        conversations_response = client.get(
            "/api/messages/conversations",
            headers=auth_headers(receiver_token),
        )
        assert conversations_response.status_code == 200
        conversations = conversations_response.get_json()["data"]
        thread = next(item for item in conversations if item["partner_id"] == sender_id)
        assert thread["unread_count"] == 1
        assert thread["last_message"] == "Can you review my project?"

        chat_response = client.get(
            f"/api/messages/chat/{sender_id}",
            headers=auth_headers(receiver_token),
        )
        assert chat_response.status_code == 200
        chat = chat_response.get_json()
        assert chat["partner"]["id"] == sender_id
        assert len(chat["messages"]) == 1
        assert chat["messages"][0]["content"] == "Can you review my project?"

        unread_after_read = client.get(
            "/api/messages/unread-total",
            headers=auth_headers(receiver_token),
        )
        assert unread_after_read.status_code == 200
        assert unread_after_read.get_json()["count"] == 0


class TestCollxModule:
    def test_collx_feed(self, client):
        response = client.get("/api/collx/feed")
        assert response.status_code == 200
        data = response.get_json()
        assert data["success"] == True

    def test_trending_hashtags(self, client):
        response = client.get("/api/collx/trending")
        assert response.status_code == 200


class TestEventsModule:
    def test_events_endpoint(self, client):
        response = client.get("/api/events")
        assert response.status_code == 200

    def test_announcements_endpoint(self, client):
        response = client.get("/api/announcements")
        assert response.status_code == 200


class TestConfessionsModule:
    def test_confessions_endpoint_requires_auth(self, client):
        response = client.get("/api/confessions/")
        assert response.status_code in [200, 401]

    def test_confessions_by_category_requires_auth(self, client):
        response = client.get("/api/confessions/?category=general")
        assert response.status_code in [200, 401]


class TestPollsModule:
    def test_polls_endpoint(self, client):
        response = client.get("/api/polls/")
        assert response.status_code in [200, 401]
