"""
JWT Authentication Utilities - Enhanced Security
Production-ready JWT handling with refresh tokens and blacklisting
"""
import jwt
import datetime
import secrets
import hashlib
from functools import wraps
from flask import request, jsonify, current_app, g
from database.models import db, UserAccount
from utils.cache_store import cache_get, cache_set, clear_memory_cache
from utils.time import utc_now

TOKEN_BLACKLIST_PREFIX = "jwt:blacklist:"


def generate_token(user_id, secret_key, expiry_hours=72, token_type='access'):
    """
    Generate JWT token for authenticated user
    
    Args:
        user_id: User ID to encode in token
        secret_key: Secret key for signing
        expiry_hours: Token validity in hours
        token_type: 'access' or 'refresh'
    
    Returns:
        Encoded JWT token string
    """
    now = utc_now()
    payload = {
        'user_id': user_id,
        'exp': now + datetime.timedelta(hours=expiry_hours),
        'iat': now,
        'nbf': now,  # Not valid before
        'jti': secrets.token_urlsafe(16),  # Unique token ID
        'type': token_type,
    }
    
    # Add fingerprint for extra security
    payload['fingerprint'] = _generate_fingerprint(user_id, payload['jti'])
    
    return jwt.encode(payload, secret_key, algorithm='HS256')


def generate_refresh_token(user_id, secret_key):
    """Generate long-lived refresh token"""
    return generate_token(user_id, secret_key, expiry_hours=720, token_type='refresh')  # 30 days


def decode_token(token, secret_key, verify_exp=True):
    """
    Decode and validate JWT token
    
    Args:
        token: JWT token string
        secret_key: Secret key for verification
        verify_exp: Whether to verify expiration
    
    Returns:
        User ID if valid, None otherwise
    """
    try:
        if is_token_blacklisted(token):
            return None
        
        payload = jwt.decode(
            token, 
            secret_key, 
            algorithms=['HS256'],
            options={'verify_exp': verify_exp}
        )
        
        # Verify fingerprint
        expected_fingerprint = _generate_fingerprint(payload['user_id'], payload['jti'])
        if payload.get('fingerprint') != expected_fingerprint:
            return None
        
        return payload['user_id']
    
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None
    except KeyError:
        return None


def decode_token_payload(token, secret_key, verify_exp=True):
    """Decode and validate a JWT token, returning the full payload."""
    try:
        if is_token_blacklisted(token):
            return None

        payload = jwt.decode(
            token,
            secret_key,
            algorithms=['HS256'],
            options={'verify_exp': verify_exp},
        )

        expected_fingerprint = _generate_fingerprint(payload['user_id'], payload['jti'])
        if payload.get('fingerprint') != expected_fingerprint:
            return None

        return payload
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError, KeyError):
        return None


def blacklist_token(token):
    """Add token to blacklist until its JWT expiry."""
    ttl_seconds = _token_ttl_seconds(token)
    cache_set(_blacklist_key(token), "1", ttl_seconds)


def is_token_blacklisted(token):
    """Return True when a token has been revoked."""
    return cache_get(_blacklist_key(token)) == "1"


def clear_token_blacklist():
    """Test helper to reset fallback blacklist state."""
    clear_memory_cache()


def _blacklist_key(token):
    digest = hashlib.sha256(token.encode()).hexdigest()
    return f"{TOKEN_BLACKLIST_PREFIX}{digest}"


def _token_ttl_seconds(token):
    try:
        payload = jwt.decode(
            token,
            current_app.config['JWT_SECRET'],
            algorithms=['HS256'],
            options={'verify_exp': False},
        )
        expires_at = datetime.datetime.fromtimestamp(payload['exp'])
        ttl = int((expires_at - utc_now()).total_seconds())
        return max(ttl, 1)
    except Exception:
        return 24 * 60 * 60


def _generate_fingerprint(user_id, jti):
    """Generate token fingerprint for additional security"""
    data = f"{user_id}:{jti}"
    return hashlib.sha256(data.encode()).hexdigest()[:16]


def token_required(f):
    """
    Decorator to protect routes with JWT authentication
    
    Usage:
        @auth_bp.route('/protected')
        @token_required
        def protected_route(user_id):
            return jsonify({'user_id': user_id})
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        error_message = None
        
        # Get token from Authorization header
        auth_header = request.headers.get('Authorization', '')
        
        if auth_header:
            if auth_header.startswith('Bearer '):
                token = auth_header.split(' ')[1]
            elif auth_header.startswith('Token '):
                token = auth_header.split(' ')[1]
        
        if not token:
            return jsonify({
                'success': False,
                'error': 'Authentication required',
                'error_code': 'AUTH_TOKEN_MISSING'
            }), 401
        
        # Decode and validate token
        user_id = decode_token(token, current_app.config['JWT_SECRET'])
        
        if user_id is None:
            # Check if token is expired
            try:
                auth_header = request.headers.get('Authorization', '')
                if auth_header.startswith('Bearer '):
                    token = auth_header.split(' ')[1]
                    payload = jwt.decode(token, current_app.config['JWT_SECRET'], algorithms=['HS256'], options={'verify_exp': False})
                    if utc_now() > datetime.datetime.fromtimestamp(payload['exp']):
                        error_message = 'Token has expired'
            except:
                pass
            
            return jsonify({
                'success': False,
                'error': error_message or 'Invalid or expired token',
                'error_code': 'AUTH_TOKEN_INVALID'
            }), 401
        
        # Verify user still exists and is active
        user = db.session.get(UserAccount, user_id)
        if not user or not user.is_active:
            return jsonify({
                'success': False,
                'error': 'User not found or inactive',
                'error_code': 'AUTH_USER_INACTIVE'
            }), 401
        
        # Store user info in Flask's g object for access in route
        g.current_user = user
        g.user_id = user_id
        
        # Pass user_id to the route function
        return f(user_id, *args, **kwargs)
    
    return decorated


def optional_token(f):
    """
    Decorator that extracts user_id if token present, None otherwise
    Useful for public endpoints that have extra features for logged-in users
    
    Usage:
        @collx_bp.route('/feed')
        @optional_token
        def feed(user_id):
            if user_id:
                # Return personalized feed
            else:
                # Return public feed
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        user_id = None
        auth_header = request.headers.get('Authorization', '')
        
        if auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            user_id = decode_token(token, current_app.config['JWT_SECRET'])
        
        g.user_id = user_id
        return f(user_id, *args, **kwargs)
    
    return decorated


def admin_required(f):
    """
    Decorator to restrict routes to admin users only
    
    Usage:
        @admin_bp.route('/users')
        @admin_required
        def get_all_users(user_id):
            # Only admins can access
    """
    @wraps(f)
    @token_required
    def decorated(user_id, *args, **kwargs):
        user = db.session.get(UserAccount, user_id)
        
        if not user or not user.is_admin:
            return jsonify({
                'success': False,
                'error': 'Admin access required',
                'error_code': 'AUTH_ADMIN_REQUIRED'
            }), 403
        
        return f(user_id, *args, **kwargs)
    
    return decorated


def verify_password(user_id, password):
    """
    Verify user password
    
    Args:
        user_id: User ID
        password: Plain text password
    
    Returns:
        User object if valid, None otherwise
    """
    user = db.session.get(UserAccount, user_id)
    if user and user.check_password(password):
        return user
    return None


def refresh_access_token(refresh_token_str):
    """
    Generate new access token using refresh token
    
    Args:
        refresh_token_str: Valid refresh token
    
    Returns:
        New access token or None
    """
    secret_key = current_app.config['JWT_SECRET']
    payload = decode_token_payload(refresh_token_str, secret_key)
    
    if payload and payload.get('type') == 'refresh':
        user_id = payload['user_id']
        # Blacklist old refresh token
        blacklist_token(refresh_token_str)
        # Generate new tokens
        new_access = generate_token(user_id, secret_key, expiry_hours=72)
        new_refresh = generate_refresh_token(user_id, secret_key)
        return {
            'access_token': new_access,
            'refresh_token': new_refresh
        }
    
    return None


def get_token_from_request():
    """Extract token from request headers"""
    auth_header = request.headers.get('Authorization', '')
    if auth_header.startswith('Bearer '):
        return auth_header.split(' ')[1]
    return None


def get_current_user():
    """Get current authenticated user from request context"""
    return getattr(g, 'current_user', None)


def get_current_user_id():
    """Get current authenticated user ID from request context"""
    return getattr(g, 'user_id', None)
