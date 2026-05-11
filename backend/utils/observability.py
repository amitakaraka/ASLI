"""Request correlation, structured logs, and consistent API errors."""
import json
import logging
import time
import uuid

from flask import g, jsonify, request

logger = logging.getLogger("asli.request")


def init_observability(app):
    """Attach request IDs, timing headers, and structured request logs."""
    @app.before_request
    def assign_request_context():
        incoming_id = request.headers.get("X-Request-ID", "").strip()
        g.request_id = incoming_id or uuid.uuid4().hex
        g.request_started_at = time.perf_counter()

    @app.after_request
    def add_observability_headers(response):
        duration_ms = int((time.perf_counter() - g.get("request_started_at", time.perf_counter())) * 1000)
        response.headers["X-Request-ID"] = g.get("request_id", "")
        response.headers["X-Response-Time-ms"] = str(duration_ms)
        logger.info(json.dumps({
            "event": "request_completed",
            "request_id": g.get("request_id"),
            "method": request.method,
            "path": request.path,
            "status": response.status_code,
            "duration_ms": duration_ms,
            "remote_addr": request.headers.get("X-Forwarded-For", request.remote_addr),
        }, separators=(",", ":")))
        return response


def error_response(message, status_code, error_code, details=None):
    """Return a consistent JSON error response with request correlation."""
    payload = {
        "success": False,
        "error": message,
        "error_code": error_code,
        "request_id": g.get("request_id"),
    }
    if details:
        payload["details"] = details
    return jsonify(payload), status_code
