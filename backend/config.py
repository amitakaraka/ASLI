"""
ASLI Backend Configuration
"""
import os


def _csv_env(name, default):
    value = os.environ.get(name, default)
    if value == "*":
        return "*"
    return [item.strip() for item in value.split(",") if item.strip()]


def _database_url():
    value = os.environ.get('DATABASE_URL', 'sqlite:///database.db')
    if value.startswith('postgres://'):
        return value.replace('postgres://', 'postgresql+psycopg://', 1)
    if value.startswith('postgresql://'):
        return value.replace('postgresql://', 'postgresql+psycopg://', 1)
    return value


class Config:
    """Base configuration"""
    SECRET_KEY = os.environ.get('SECRET_KEY')
    JWT_SECRET = os.environ.get('JWT_SECRET')
    OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY')
    JWT_EXPIRY_HOURS = 72
    JWT_REFRESH_EXPIRY_HOURS = int(os.environ.get('JWT_REFRESH_EXPIRY_HOURS', '720'))
    SQLALCHEMY_DATABASE_URI = _database_url()
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    REDIS_URL = os.environ.get('REDIS_URL')
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB upload limit
    AUTO_MIGRATE = os.environ.get('ASLI_AUTO_MIGRATE', '').lower() in {'1', 'true', 'yes'}
    SEED_DEMO_DATA = os.environ.get('ASLI_SEED_DEMO_DATA', '').lower() in {'1', 'true', 'yes'}
    CORS_ORIGINS = _csv_env('ASLI_CORS_ORIGINS', '*')
    AUTH_RATE_LIMIT_PER_MINUTE = int(os.environ.get('ASLI_AUTH_RATE_LIMIT_PER_MINUTE', '30'))
    CHAT_RATE_LIMIT_PER_MINUTE = int(os.environ.get('ASLI_CHAT_RATE_LIMIT_PER_MINUTE', '60'))

    @classmethod
    def validate(cls):
        """Fail fast if required runtime secrets are missing."""
        missing = [
            name for name in ('SECRET_KEY', 'JWT_SECRET')
            if not getattr(cls, name)
        ]
        if missing:
            raise RuntimeError(
                f"Missing required environment variable(s): {', '.join(missing)}"
            )
        weak = [
            name for name in ('SECRET_KEY', 'JWT_SECRET')
            if len(getattr(cls, name)) < 32
        ]
        if weak:
            raise RuntimeError(
                f"Environment variable(s) must be at least 32 characters: {', '.join(weak)}"
            )
        is_production = os.environ.get('ASLI_ENV', '').lower() == 'production'
        if is_production and cls.CORS_ORIGINS == "*":
            raise RuntimeError(
                "ASLI_CORS_ORIGINS must be set to explicit origins when ASLI_ENV=production"
            )


class DevelopmentConfig(Config):
    DEBUG = True


class ProductionConfig(Config):
    DEBUG = False
