"""Redis-backed cache helpers with an in-memory fallback for local runs."""
import logging
import time

from flask import current_app, has_app_context

logger = logging.getLogger(__name__)

_memory_values = {}
_memory_expiries = {}
_redis_client = None
_redis_url = None
_redis_unavailable_logged = False


def get_redis_client():
    """Return a cached Redis client when REDIS_URL is configured and reachable."""
    global _redis_client, _redis_url, _redis_unavailable_logged

    if not has_app_context():
        return None

    redis_url = current_app.config.get("REDIS_URL")
    if not redis_url:
        return None

    if _redis_client is not None and _redis_url == redis_url:
        return _redis_client

    try:
        import redis

        client = redis.Redis.from_url(
            redis_url,
            decode_responses=True,
            socket_connect_timeout=1,
            socket_timeout=1,
        )
        client.ping()
        _redis_client = client
        _redis_url = redis_url
        return _redis_client
    except Exception as exc:
        _redis_client = None
        _redis_url = redis_url
        if not _redis_unavailable_logged:
            logger.warning("Redis unavailable, using in-memory fallback: %s", exc)
            _redis_unavailable_logged = True
        return None


def _purge_expired(key):
    expires_at = _memory_expiries.get(key)
    if expires_at is not None and expires_at <= time.time():
        _memory_values.pop(key, None)
        _memory_expiries.pop(key, None)


def cache_get(key):
    client = get_redis_client()
    if client:
        return client.get(key)

    _purge_expired(key)
    return _memory_values.get(key)


def cache_set(key, value, ttl_seconds):
    client = get_redis_client()
    ttl_seconds = max(1, int(ttl_seconds))
    if client:
        client.setex(key, ttl_seconds, value)
        return

    _memory_values[key] = str(value)
    _memory_expiries[key] = time.time() + ttl_seconds


def cache_incr(key, ttl_seconds):
    client = get_redis_client()
    ttl_seconds = max(1, int(ttl_seconds))
    if client:
        value = int(client.incr(key))
        if value == 1:
            client.expire(key, ttl_seconds)
        return value

    _purge_expired(key)
    value = int(_memory_values.get(key, "0")) + 1
    _memory_values[key] = str(value)
    _memory_expiries.setdefault(key, time.time() + ttl_seconds)
    return value


def cache_delete(key):
    client = get_redis_client()
    if client:
        client.delete(key)
        return

    _memory_values.pop(key, None)
    _memory_expiries.pop(key, None)


def clear_memory_cache():
    """Test helper to reset fallback cache state."""
    _memory_values.clear()
    _memory_expiries.clear()
