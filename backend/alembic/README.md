# Alembic Database Migrations

This directory manages database schema migrations for the ASLI backend.

## Setup

1. Install dependencies:
```bash
pip install alembic
```

2. Initialize Alembic (if not already done):
```bash
cd backend
alembic init migrations
```

3. Configure `alembic.ini` to point to your database:
```ini
sqlalchemy.url = sqlite:///asli.db
```

4. Configure `migrations/env.py` to use your models:
```python
from database.models import db
target_metadata = db.metadata
```

## Usage

### Create a new migration
```bash
cd backend
alembic revision --autogenerate -m "Add user_preferences table"
```

### Apply migrations
```bash
alembic upgrade head
```

### Rollback
```bash
alembic downgrade -1
```

### Check current version
```bash
alembic current
```

### Show migration history
```bash
alembic history
```

## Workflow

1. Make changes to models in `database/models.py`
2. Run `alembic revision --autogenerate -m "description"`
3. Review the generated migration file
4. Run `alembic upgrade head` to apply

## For Production (PostgreSQL)

When deploying to production with PostgreSQL:

```bash
export DATABASE_URL=postgresql://user:pass@host:5432/asli_db
alembic upgrade head
```
