# Vercel Deployment Notes

Vercel can run the Flask HTTP API as a Python Function, but this backend is still a better natural fit for Render/Fly/Railway-style long-running services.

## What Works

- Flask HTTP routes.
- JWT auth, admin routes, feed routes, chat HTTP routes, analytics, and health checks.
- External Postgres via `DATABASE_URL`.
- Redis-backed token blacklist/rate limits via `REDIS_URL`.

## What Does Not Fully Fit Vercel

- Socket.IO/WebSocket features are not a good match for Vercel Functions.
- Local uploads are ephemeral and should be moved to Vercel Blob, S3, Cloudinary, or another object store.
- SQLite should not be used in production on Vercel.
- Migrations should run during deploy/build or manually before promotion, not on request.

## Suggested Vercel Project Settings

- Root Directory: `backend`
- Install Command: `python -m pip install -r requirements.txt`
- Build Command: leave empty for smoke deploys; run `alembic upgrade head` manually or from CI for production Postgres.
- Output Directory: leave empty

## Required Environment Variables

- `SECRET_KEY`
- `JWT_SECRET`
- `DATABASE_URL`
- `ASLI_ENV=production`
- `ASLI_CORS_ORIGINS=<your Flutter/web origins>`
- `ASLI_AUTO_MIGRATE=0`
- `ASLI_SEED_DEMO_DATA=0`
- `ASLI_SOCKETIO_ASYNC_MODE=threading`

Recommended:

- `REDIS_URL`
- `OPENAI_API_KEY` if AI-backed features are enabled later

## Smoke Checks

After deploy:

```bash
curl https://<your-vercel-domain>/health
curl https://<your-vercel-domain>/ready
```
