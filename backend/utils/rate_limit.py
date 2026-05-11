"""Rate limiting helpers for abuse-prone endpoints."""
from functools import wraps

from flask import current_app, jsonify, request
from utils.cache_store import cache_incr, clear_memory_cache


def _client_key(scope):
    forwarded_for = request.headers.get("X-Forwarded-For", "")
    ip = forwarded_for.split(",")[0].strip() if forwarded_for else request.remote_addr
    return f"rate-limit:{scope}:{ip or 'unknown'}"


def rate_limit(config_key, scope):
    """Limit requests per minute using an app config integer."""
    def decorator(fn):
        @wraps(fn)
        def wrapped(*args, **kwargs):
            limit = int(current_app.config.get(config_key, 0) or 0)
            if limit <= 0:
                return fn(*args, **kwargs)

            count = cache_incr(_client_key(scope), 60)
            if count > limit:
                return jsonify({
                    "success": False,
                    "error": "Too many requests. Please try again shortly.",
                    "error_code": "RATE_LIMITED",
                }), 429

            return fn(*args, **kwargs)
        return wrapped
    return decorator


def clear_rate_limits():
    """Test helper to reset fallback rate limit state."""
    clear_memory_cache()
