"""
Auth Routes - Enhanced Security & Validation
Production-ready authentication with comprehensive error handling
"""
from flask import Blueprint, request, jsonify, current_app
from database.models import db, UserAccount
from modules.auth.jwt_utils import generate_token, token_required, blacklist_token, get_token_from_request
from utils.rate_limit import rate_limit
import re
import logging

logger = logging.getLogger(__name__)

auth_bp = Blueprint('auth', __name__, url_prefix='/api/auth')


# VALIDATION HELPERS

def validate_email(email):
    """Validate email format with regex"""
    if not email or len(email) > 150:
        return False
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None


def validate_username(username):
    """Validate username format"""
    if not username or len(username) < 3 or len(username) > 20:
        return False
    pattern = r'^[a-zA-Z0-9_]{3,20}$'
    return re.match(pattern, username) is not None


def validate_password(password):
    """
    Validate password strength
    Requirements: min 6 characters
    """
    if not password or len(password) < 6:
        return False, "Password must be at least 6 characters"
    if len(password) > 128:
        return False, "Password is too long"
    return True, None


def validate_name(name):
    """Validate user name"""
    if not name or len(name.strip()) < 2 or len(name.strip()) > 100:
        return False
    return True


def sanitize_string(text):
    """Sanitize string input"""
    if not text:
        return ""
    return text.strip()[:500]


# AUTH ROUTES

@auth_bp.route('/register', methods=['POST'])
@rate_limit('AUTH_RATE_LIMIT_PER_MINUTE', 'auth-register')
def register():
    """
    Register a new user account
    
    Required fields:
        - name: User's full name
        - email: Valid email address
        - password: Password (min 6 chars)
        - username: Unique username (3-20 chars)
    
    Optional fields:
        - department: Department/major
        - year: Academic year
    """
    try:
        # Parse request body
        data = request.get_json()
        
        if not data:
            logger.warning("Registration attempt with empty body")
            return jsonify({
                'success': False,
                'error': 'Request body required',
                'error_code': 'VALIDATION_EMPTY_BODY'
            }), 400
        
        # Extract and sanitize fields
        name = sanitize_string(data.get('name', ''))
        email = sanitize_string(data.get('email', '')).lower()
        password = data.get('password', '')
        username = sanitize_string(data.get('username', '')).lower()
        department = sanitize_string(data.get('department', ''))
        year = sanitize_string(data.get('year', ''))
        
        # Validate required fields
        validation_errors = []
        
        if not validate_name(name):
            validation_errors.append("Name must be between 2 and 100 characters")
        
        if not validate_email(email):
            validation_errors.append("Valid email address required")
        
        password_valid, password_error = validate_password(password)
        if not password_valid:
            validation_errors.append(password_error)
        
        if not validate_username(username):
            validation_errors.append("Username must be 3-20 characters (alphanumeric and underscore only)")
        
        if validation_errors:
            return jsonify({
                'success': False,
                'error': 'Validation failed',
                'errors': validation_errors,
                'error_code': 'VALIDATION_FAILED'
            }), 400
        
        # Check for existing user
        existing_user = UserAccount.query.filter(
            (UserAccount.email == email) | (UserAccount.username == username)
        ).first()
        
        if existing_user:
            if existing_user.email == email:
                return jsonify({
                    'success': False,
                    'error': 'Email already registered',
                    'error_code': 'EMAIL_EXISTS'
                }), 409
            
            if existing_user.username == username:
                return jsonify({
                    'success': False,
                    'error': 'Username already taken',
                    'error_code': 'USERNAME_EXISTS'
                }), 409
        
        # Create new user
        user = UserAccount(
            name=name,
            email=email,
            username=username,
            department=department,
            year=year,
        )
        user.set_password(password)
        
        db.session.add(user)
        db.session.commit()
        
        logger.info(f"New user registered: {username} (ID: {user.id})")
        
        # Generate JWT tokens
        token = generate_token(
            user.id,
            current_app.config['JWT_SECRET'],
            expiry_hours=current_app.config.get('JWT_EXPIRY_HOURS', 72)
        )
        refresh_token = generate_token(
            user.id,
            current_app.config['JWT_SECRET'],
            expiry_hours=current_app.config.get('JWT_REFRESH_EXPIRY_HOURS', 720),
            token_type='refresh',
        )
        
        return jsonify({
            'success': True,
            'message': 'Account created successfully',
            'token': token,
            'refresh_token': refresh_token,
            'user': user.to_dict()
        }), 201
    
    except Exception as e:
        logger.error(f"Registration error: {str(e)}", exc_info=True)
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Registration failed. Please try again.',
            'error_code': 'SERVER_ERROR'
        }), 500


@auth_bp.route('/login', methods=['POST'])
@rate_limit('AUTH_RATE_LIMIT_PER_MINUTE', 'auth-login')
def login():
    """
    Login with email/username + password
    
    Required fields:
        - email: Email address or username
        - password: User's password
    """
    try:
        # Parse request body
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': 'Request body required',
                'error_code': 'VALIDATION_EMPTY_BODY'
            }), 400
        
        identifier = sanitize_string(data.get('email', '')).lower()
        password = data.get('password', '')
        
        if not identifier or not password:
            return jsonify({
                'success': False,
                'error': 'Email/username and password required',
                'error_code': 'VALIDATION_MISSING_FIELDS'
            }), 400
        
        # Find user by email or username
        user = UserAccount.query.filter(
            (UserAccount.email == identifier) | (UserAccount.username == identifier)
        ).first()
        
        if not user:
            logger.warning(f"Login attempt with unknown identifier: {identifier}")
            return jsonify({
                'success': False,
                'error': 'Invalid credentials',
                'error_code': 'AUTH_INVALID_CREDENTIALS'
            }), 401
        
        # Check password
        if not user.check_password(password):
            logger.warning(f"Login attempt with wrong password for: {user.username}")
            return jsonify({
                'success': False,
                'error': 'Invalid credentials',
                'error_code': 'AUTH_INVALID_CREDENTIALS'
            }), 401
        
        # Check if account is active
        if not user.is_active:
            logger.warning(f"Login attempt for inactive account: {user.username}")
            return jsonify({
                'success': False,
                'error': 'Account is deactivated. Please contact support.',
                'error_code': 'AUTH_ACCOUNT_INACTIVE'
            }), 403
        
        logger.info(f"User logged in: {user.username} (ID: {user.id})")
        
        # Generate JWT tokens
        token = generate_token(
            user.id,
            current_app.config['JWT_SECRET'],
            expiry_hours=current_app.config.get('JWT_EXPIRY_HOURS', 72)
        )
        refresh_token = generate_token(
            user.id,
            current_app.config['JWT_SECRET'],
            expiry_hours=current_app.config.get('JWT_REFRESH_EXPIRY_HOURS', 720),
            token_type='refresh',
        )
        
        return jsonify({
            'success': True,
            'message': 'Login successful',
            'token': token,
            'refresh_token': refresh_token,
            'user': user.to_dict()
        })
    
    except Exception as e:
        logger.error(f"Login error: {str(e)}", exc_info=True)
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Login failed. Please try again.',
            'error_code': 'SERVER_ERROR'
        }), 500


@auth_bp.route('/logout', methods=['POST'])
@token_required
def logout(user_id):
    """
    Logout - invalidate current token
    
    Security: Requires valid JWT token
    """
    try:
        token = get_token_from_request()
        if token:
            blacklist_token(token)
        
        logger.info(f"User logged out: {user_id}")
        
        return jsonify({
            'success': True,
            'message': 'Logged out successfully'
        })
    
    except Exception as e:
        logger.error(f"Logout error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Logout failed',
            'error_code': 'SERVER_ERROR'
        }), 500


@auth_bp.route('/me', methods=['GET'])
@token_required
def get_profile(user_id):
    """
    Get current user's profile
    
    Security: Requires valid JWT token
    """
    try:
        user = db.session.get(UserAccount, user_id)
        
        if not user:
            return jsonify({
                'success': False,
                'error': 'User not found',
                'error_code': 'USER_NOT_FOUND'
            }), 404
        
        return jsonify({
            'success': True,
            'user': user.to_dict(include_email=True)
        })
    
    except Exception as e:
        logger.error(f"Get profile error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to fetch profile',
            'error_code': 'SERVER_ERROR'
        }), 500


@auth_bp.route('/me', methods=['PUT'])
@token_required
def update_profile(user_id):
    """
    Update current user's profile
    
    Updatable fields:
        - name
        - bio (max 160 chars)
        - department
        - year
        - profile_color
    
    Security: Requires valid JWT token
    """
    try:
        user = db.session.get(UserAccount, user_id)
        
        if not user:
            return jsonify({
                'success': False,
                'error': 'User not found',
                'error_code': 'USER_NOT_FOUND'
            }), 404
        
        data = request.get_json() or {}
        update_fields = {}
        errors = []
        
        # Validate and collect fields to update
        if 'name' in data:
            name = sanitize_string(data['name'])
            if not validate_name(name):
                errors.append("Name must be between 2 and 100 characters")
            else:
                update_fields['name'] = name
        
        if 'bio' in data:
            bio = sanitize_string(data['bio'])[:160]
            update_fields['bio'] = bio
        
        if 'department' in data:
            update_fields['department'] = sanitize_string(data['department'])
        
        if 'year' in data:
            update_fields['year'] = sanitize_string(data['year'])
        
        if 'profile_color' in data:
            color = sanitize_string(data['profile_color'])
            # Validate hex color
            if re.match(r'^#[0-9A-Fa-f]{6}$', color):
                update_fields['profile_color'] = color
            else:
                errors.append("Invalid color format. Use hex format: #RRGGBB")
        
        if 'avatar_url' in data:
            update_fields['avatar_url'] = sanitize_string(data['avatar_url'])
        
        if errors:
            return jsonify({
                'success': False,
                'error': 'Validation failed',
                'errors': errors,
                'error_code': 'VALIDATION_FAILED'
            }), 400
        
        # Apply updates
        for field, value in update_fields.items():
            setattr(user, field, value)
        
        db.session.commit()
        
        logger.info(f"Profile updated for user: {user.username}")
        
        return jsonify({
            'success': True,
            'message': 'Profile updated successfully',
            'user': user.to_dict(include_email=True)
        })
    
    except Exception as e:
        logger.error(f"Update profile error: {str(e)}")
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Failed to update profile',
            'error_code': 'SERVER_ERROR'
        }), 500


@auth_bp.route('/refresh', methods=['POST'])
def refresh_token():
    """
    Refresh access token using refresh token
    
    Required fields:
        - refresh_token: Valid refresh token
    """
    try:
        data = request.get_json()
        
        if not data or 'refresh_token' not in data:
            return jsonify({
                'success': False,
                'error': 'Refresh token required',
                'error_code': 'VALIDATION_MISSING_TOKEN'
            }), 400
        
        from modules.auth.jwt_utils import refresh_access_token
        
        result = refresh_access_token(data['refresh_token'])
        
        if result:
            return jsonify({
                'success': True,
                'access_token': result['access_token'],
                'refresh_token': result['refresh_token']
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Invalid or expired refresh token',
                'error_code': 'AUTH_INVALID_REFRESH_TOKEN'
            }), 401
    
    except Exception as e:
        logger.error(f"Token refresh error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Token refresh failed',
            'error_code': 'SERVER_ERROR'
        }), 500


@auth_bp.route('/check-username/<username>', methods=['GET'])
def check_username_availability(username):
    """
    Check if username is available
    
    Returns:
        - available: boolean
    """
    try:
        if not validate_username(username):
            return jsonify({
                'success': False,
                'error': 'Invalid username format',
                'error_code': 'VALIDATION_INVALID_USERNAME'
            }), 400
        
        user = UserAccount.query.filter_by(username=username.lower()).first()
        
        return jsonify({
            'success': True,
            'available': user is None,
            'username': username
        })
    
    except Exception as e:
        logger.error(f"Username check error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to check username',
            'error_code': 'SERVER_ERROR'
        }), 500


@auth_bp.route('/check-email/<email>', methods=['GET'])
def check_email_availability(email):
    """
    Check if email is available
    
    Returns:
        - available: boolean
    """
    try:
        if not validate_email(email):
            return jsonify({
                'success': False,
                'error': 'Invalid email format',
                'error_code': 'VALIDATION_INVALID_EMAIL'
            }), 400
        
        user = UserAccount.query.filter_by(email=email.lower()).first()
        
        return jsonify({
            'success': True,
            'available': user is None,
            'email': email
        })
    
    except Exception as e:
        logger.error(f"Email check error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to check email',
            'error_code': 'SERVER_ERROR'
        }), 500


@auth_bp.route('/delete-account', methods=['POST'])
@token_required
def delete_account(user_id):
    """
    Delete current user's account (soft delete)
    
    Security: Requires valid JWT token and password confirmation
    """
    try:
        data = request.get_json()
        
        if not data or 'password' not in data:
            return jsonify({
                'success': False,
                'error': 'Password confirmation required',
                'error_code': 'VALIDATION_MISSING_PASSWORD'
            }), 400
        
        user = db.session.get(UserAccount, user_id)
        
        if not user:
            return jsonify({
                'success': False,
                'error': 'User not found',
                'error_code': 'USER_NOT_FOUND'
            }), 404
        
        # Verify password
        if not user.check_password(data['password']):
            return jsonify({
                'success': False,
                'error': 'Incorrect password',
                'error_code': 'AUTH_INVALID_PASSWORD'
            }), 401
        
        # Soft delete
        user.is_active = False
        # In production, you might want to anonymize data instead
        user.email = f"deleted_{user.id}@deleted.local"
        user.username = f"deleted_{user.id}"
        
        db.session.commit()
        
        # Blacklist current token
        token = get_token_from_request()
        if token:
            blacklist_token(token)
        
        logger.warning(f"Account deleted: {user_id}")
        
        return jsonify({
            'success': True,
            'message': 'Account deleted successfully'
        })
    
    except Exception as e:
        logger.error(f"Delete account error: {str(e)}")
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Failed to delete account',
            'error_code': 'SERVER_ERROR'
        }), 500
