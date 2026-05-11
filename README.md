# ASLI Campus Platform

ASLI is a full-stack campus community platform built with a Flutter mobile app and a Flask backend. It combines campus social networking, messaging, events, Q&A, study groups, marketplace listings, anonymous confessions, polls, stories, notifications, analytics, admin tools, and an AI campus assistant.

The project is structured as a production-oriented monorepo:

- `asli_app/` - Flutter app for Android, iOS, web, macOS, and desktop targets.
- `backend/` - Flask API with SQLAlchemy models, modular route blueprints, JWT auth, health checks, Socket.IO handlers, and Vercel/Render deployment support.
- `nginx/` - Reverse proxy configuration for traditional server deployments.
- `docker-compose.yml` - Local/container deployment entry point.

## Current Deployment

The backend is currently deployed on Vercel:

```text
https://backend-eight-weld-88.vercel.app
```

Verified endpoints:

- `GET /`
- `GET /health`
- `GET /ready`
- `POST /api/auth/login`
- `POST /api/chat/message`
- `GET /api/collx/feed`

Important production note: the current Vercel deployment can run the HTTP API, but Vercel Functions are not ideal for long-running Socket.IO/WebSocket workloads. For durable production, use Postgres for the database, Redis for token/rate-limit state, and external object storage for uploads.

## Features

### Mobile App

- Email/password authentication with secure token storage.
- Home dashboard for campus modules.
- CollX social feed with posts, replies, likes, follows, bookmarks, and profiles.
- AI chat screen for campus assistant workflows.
- Direct messaging and group chat screens.
- Campus events and RSVP flows.
- Study groups and community channels.
- Marketplace listings.
- Anonymous confessions.
- Polls, stories, leaderboard, notifications, analytics, and admin views.
- Offline/cache-oriented services, connectivity handling, retry logic, and structured API clients.
- Android release APK support.
- iOS project support, requiring full Xcode and Apple signing for installable builds.

### Backend

- Flask application factory with modular blueprints.
- JWT authentication and refresh-token support.
- SQLAlchemy data models.
- Health and readiness endpoints.
- Config validation for required secrets.
- Environment-only secrets for production.
- Optional demo seeding and schema creation for local/testing environments.
- Redis-backed helpers for cache/rate-limit/token state when `REDIS_URL` is configured.
- Socket.IO handlers for realtime features on long-running server hosts.
- Vercel-compatible entry point in `backend/api/index.py`.
- Alembic migration scaffolding.
- Pytest backend test suite.

## Tech Stack

### Frontend

- Flutter
- Dart
- Riverpod
- Hive and SharedPreferences
- flutter_secure_storage
- HTTP, WebSocket, and Socket.IO clients
- Firebase Core, Messaging, and Analytics
- Google Maps and geolocation plugins

### Backend

- Python
- Flask
- Flask-CORS
- Flask-SocketIO
- SQLAlchemy
- PyJWT
- Gunicorn
- Eventlet for long-running Socket.IO deployments
- Redis support
- SQLite for local development
- PostgreSQL support through `psycopg`

### Deployment

- Vercel for serverless HTTP API deployment
- Render/Fly/Railway-style hosts recommended for long-running backend deployments
- Docker and Docker Compose support
- Nginx reverse proxy configuration

## Architecture

ASLI follows a modular client-server architecture. The Flutter app owns the user experience, local state, offline/cache behavior, and device integrations. The Flask backend owns authentication, business logic, persistence, realtime events, health checks, and API contracts.

```text
Flutter App
  |-- Screens
  |-- Riverpod providers
  |-- Services
  |-- API client
  |-- Socket client
  |
  | HTTPS / WSS
  v
Flask Backend
  |-- app.py application factory
  |-- config validation
  |-- CORS
  |-- SQLAlchemy setup
  |-- feature blueprints
  |-- Socket.IO handlers
  |-- health/readiness endpoints
  |-- JSON error handlers
  |
  | persistence and infrastructure
  v
Database / Redis / Object Storage
```

### Frontend Architecture

The Flutter app is organized by responsibility:

- `screens/` contains user-facing pages such as login, feed, chat, events, marketplace, profile, and admin.
- `providers/` manages app state with Riverpod.
- `services/` handles API access, secure storage, connectivity, notifications, image upload, offline queueing, and sockets.
- `widgets/` contains reusable UI pieces such as post cards, reply cards, skeleton loaders, connection bars, and error states.
- `theme/` centralizes colors, theme extensions, and theme provider logic.
- `config/env_config.dart` controls environment-specific API and WebSocket URLs.

### Backend Architecture

The backend is built around a Flask application factory in `backend/app.py`:

- `config.py` loads runtime configuration from environment variables and fails fast when required secrets are missing.
- `database/models.py` defines the SQLAlchemy models used across modules.
- `modules/*/routes.py` files keep feature APIs isolated by domain.
- `modules/auth/jwt_utils.py` handles JWT creation and validation helpers.
- `modules/socketio_handlers.py` registers realtime messaging and notification handlers.
- `utils/` contains shared infrastructure helpers for observability, rate limiting, cache state, and time handling.
- `tests/` contains backend API tests for health, auth, chatbot, and core module behavior.

### Request Flow

```text
User action
  -> Flutter screen
  -> Riverpod provider or service
  -> Reliable API client / Socket service
  -> Flask route blueprint
  -> Auth, validation, business logic
  -> SQLAlchemy database operation
  -> JSON response or realtime event
  -> Flutter state update
  -> Updated UI
```

### Deployment Architecture

There are two supported deployment shapes:

- **Vercel HTTP deployment:** good for demos and standard REST routes. Uses `backend/api/index.py`, `backend/vercel.json`, and `ASLI_SOCKETIO_ASYNC_MODE=threading`.
- **Long-running server deployment:** recommended for full production realtime behavior. Run Flask with Gunicorn/Eventlet behind Nginx or a cloud load balancer, with Postgres, Redis, and external upload storage.

Recommended production target:

```text
Flutter Android/iOS app
  -> HTTPS / WSS
  -> Nginx or cloud load balancer
  -> Gunicorn + Flask + Socket.IO
  -> Postgres
  -> Redis
  -> Object storage
```

## Repository Layout

```text
.
├── asli_app/
│   ├── android/
│   ├── ios/
│   ├── lib/
│   │   ├── config/
│   │   ├── providers/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── theme/
│   │   ├── utils/
│   │   └── widgets/
│   ├── test/
│   └── pubspec.yaml
├── backend/
│   ├── api/
│   ├── alembic/
│   ├── database/
│   ├── modules/
│   ├── services/
│   ├── tests/
│   ├── utils/
│   ├── app.py
│   ├── config.py
│   ├── requirements.txt
│   └── vercel.json
├── nginx/
├── docker-compose.yml
└── README.md
```

## Backend Modules

The backend registers route modules for:

- Auth
- Chat and AI chat
- Q&A
- CollX feed
- Events
- Notifications
- Analytics
- Direct messages
- Admin
- Bookmarks
- Polls
- Stories
- Leaderboard
- Study groups
- Confessions
- Marketplace
- Community
- Uploads

## Environment Variables

Create environment variables locally or in your deployment provider. Do not commit real secrets.

Required:

```bash
SECRET_KEY="replace-with-a-strong-secret-at-least-32-chars"
JWT_SECRET="replace-with-a-strong-jwt-secret-at-least-32-chars"
DATABASE_URL="sqlite:///database.db"
ASLI_ENV="development"
ASLI_CORS_ORIGINS="*"
```

Recommended for production:

```bash
DATABASE_URL="postgresql://user:password@host:5432/database"
REDIS_URL="redis://default:password@host:6379"
ASLI_ENV="production"
ASLI_CORS_ORIGINS="https://your-domain.com"
ASLI_AUTO_MIGRATE="0"
ASLI_SEED_DEMO_DATA="0"
ASLI_SOCKETIO_ASYNC_MODE="threading"
```

Optional:

```bash
OPENAI_API_KEY="your-openai-api-key"
ASLI_AUTH_RATE_LIMIT_PER_MINUTE="30"
ASLI_CHAT_RATE_LIMIT_PER_MINUTE="60"
JWT_REFRESH_EXPIRY_HOURS="720"
```

## Local Backend Setup

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

For local demo data:

```bash
export SECRET_KEY="local-secret-key-local-secret-key-1234"
export JWT_SECRET="local-jwt-secret-local-jwt-secret-1234"
export DATABASE_URL="sqlite:///database.db"
export ASLI_ENV="development"
export ASLI_CORS_ORIGINS="*"
export ASLI_AUTO_MIGRATE="1"
export ASLI_SEED_DEMO_DATA="1"
```

Run the backend:

```bash
python app.py
```

Or with Gunicorn for a long-running deployment:

```bash
gunicorn --worker-class eventlet -w 1 app:app --bind 0.0.0.0:5001
```

Health checks:

```bash
curl http://localhost:5001/health
curl http://localhost:5001/ready
```

## Flutter App Setup

```bash
cd asli_app
flutter pub get
flutter run
```

The mobile API base URL is configured in:

```text
asli_app/lib/config/env_config.dart
```

Current mobile production URL:

```text
https://backend-eight-weld-88.vercel.app
```

For local web development, the app currently points web builds at:

```text
http://localhost:5050
```

Update `EnvConfig.apiBaseUrl` if your backend runs somewhere else.

## Testing

Backend tests:

```bash
cd backend
pytest
```

Flutter analyzer:

```bash
cd asli_app
dart analyze
```

Flutter tests:

```bash
cd asli_app
flutter test
```

Known recent status:

- Backend tests passing.
- Flutter analyzer clean.
- Flutter tests passing.
- Android release APK build passing.

## Build Android

```bash
cd asli_app
flutter build apk --release
```

Release output:

```text
asli_app/build/app/outputs/flutter-apk/app-release.apk
```

The current Vercel-backed APK artifact is also available locally as:

```text
asli_app/app-release-vercel.apk
```

## Build iOS

iOS builds require macOS with full Xcode installed and selected:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

Build an unsigned iOS app:

```bash
cd asli_app
flutter build ios --release --no-codesign
```

To create an installable `.ipa`, configure Apple Developer signing in Xcode, then run:

```bash
flutter build ipa --release
```

## Deploy Backend to Vercel

The backend includes Vercel configuration:

```text
backend/vercel.json
backend/api/index.py
backend/.python-version
```

Recommended Vercel project settings:

- Root Directory: `backend`
- Install Command: `python -m pip install -r requirements.txt`
- Build Command: leave empty for smoke/demo deployment, or run migrations from CI for production.
- Output Directory: leave empty.

Required Vercel environment variables:

```bash
SECRET_KEY
JWT_SECRET
DATABASE_URL
ASLI_ENV=production
ASLI_CORS_ORIGINS=https://your-frontend-origin.com
ASLI_AUTO_MIGRATE=0
ASLI_SEED_DEMO_DATA=0
ASLI_SOCKETIO_ASYNC_MODE=threading
```

After deployment:

```bash
curl https://your-vercel-domain.vercel.app/health
curl https://your-vercel-domain.vercel.app/ready
```

## Production Checklist

Before treating this as a real production system:

- Use a managed Postgres database instead of SQLite.
- Use Redis for token blacklist, rate limits, and realtime-adjacent state.
- Move uploads to object storage such as S3, Cloudinary, or Vercel Blob.
- Run Alembic migrations as the normal database update path.
- Disable demo seeding in production.
- Set explicit CORS origins.
- Rotate all deployment secrets.
- Add deeper end-to-end tests for auth, posting, messaging, admin, and payment-like marketplace flows.
- Use a long-running backend host if Socket.IO/WebSockets are required.
- Configure Firebase credentials and push notification certificates for production apps.
- Configure Apple signing for iOS release distribution.

## Useful Commands

```bash
# Backend
cd backend
pytest
python app.py

# Flutter
cd asli_app
flutter pub get
dart analyze
flutter test
flutter build apk --release

# Deployment smoke checks
curl https://backend-eight-weld-88.vercel.app/health
curl https://backend-eight-weld-88.vercel.app/ready
```

## Security Notes

- Do not commit `.env` files, real API keys, production database URLs, private signing files, or Firebase service-account secrets.
- `SECRET_KEY` and `JWT_SECRET` must be strong values of at least 32 characters.
- In production, `ASLI_CORS_ORIGINS` must be explicit and cannot be `*`.
- SQLite is acceptable for local development and quick demos, but not for durable serverless production.

## Project Status

The project has a strong working baseline:

- Backend deployed and smoke-tested on Vercel.
- Android APK built against the Vercel backend.
- Backend tests pass.
- Flutter analyzer is clean.
- Flutter tests pass.
- Secrets are environment-driven.
- Production database mutation is opt-in.

Remaining production hardening is mostly infrastructure and coverage:

- Durable Postgres database.
- Redis-backed state.
- External file storage.
- More user-flow tests.
- iOS signing and release pipeline.
- Long-running backend host for full realtime support.
