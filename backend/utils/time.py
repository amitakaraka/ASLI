from datetime import datetime, timezone


def utc_now():
    """Return a UTC timestamp compatible with existing naive DateTime columns."""
    return datetime.now(timezone.utc).replace(tzinfo=None)
