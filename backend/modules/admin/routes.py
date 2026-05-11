"""
Admin Module — Platform Management & Content Moderation
User management, content control, system overview
"""
from flask import Blueprint, request, jsonify
from database.models import db, UserAccount, CollxPost, CollxLike, CollxReply, CollxFollow, \
    Question, Answer, Notification, DirectMessage
from modules.auth.jwt_utils import token_required
from datetime import datetime, timedelta

admin_bp = Blueprint('admin', __name__, url_prefix='/api/admin')


def admin_required(f):
    """Decorator to check if user is admin"""
    from functools import wraps
    @wraps(f)
    def decorated_function(user_id, *args, **kwargs):
        user = db.session.get(UserAccount, user_id)
        if not user or not user.is_admin:
            return jsonify({
                'success': False,
                'error': 'Admin access required',
                'error_code': 'ADMIN_ACCESS_REQUIRED'
            }), 403
        return f(user_id, *args, **kwargs)
    return decorated_function


# USER MANAGEMENT

@admin_bp.route('/users', methods=['GET'])
@token_required
@admin_required
def list_users(user_id):
    """Get all users with management info"""
    users = UserAccount.query.order_by(UserAccount.id.asc()).all()
    result = []
    for u in users:
        post_count = CollxPost.query.filter_by(user_id=u.id).count()
        dm_count = DirectMessage.query.filter_by(sender_id=u.id).count()
        result.append({
            'id': u.id,
            'name': u.name,
            'username': u.username,
            'email': u.email,
            'department': u.department,
            'year': u.year,
            'bio': u.bio,
            'profile_color': u.profile_color,
            'is_active': u.is_active,
            'is_admin': u.is_admin,
            'follower_count': u.follower_count,
            'following_count': u.following_count,
            'post_count': post_count,
            'dm_count': dm_count,
            'joined': u.created_at.isoformat() if u.created_at else None,
        })
    return jsonify({'success': True, 'count': len(result), 'data': result})


@admin_bp.route('/users/<int:target_id>/toggle', methods=['POST'])
@token_required
@admin_required
def toggle_user(user_id, target_id):
    """Activate/Deactivate a user"""
    # Prevent admin from deactivating themselves
    if target_id == user_id:
        return jsonify({
            'success': False,
            'error': 'Cannot deactivate your own account',
            'error_code': 'CANNOT_SELF_DEACTIVATE'
        }), 400
    
    target = db.session.get(UserAccount, target_id)
    if not target:
        return jsonify({'success': False, 'error': 'User not found'}), 404
    
    # Keep admin accounts from being disabled through this bulk toggle endpoint.
    if target.is_admin:
        return jsonify({
            'success': False,
            'error': 'Cannot deactivate admin accounts',
            'error_code': 'CANNOT_DEACTIVATE_ADMIN'
        }), 403
    
    target.is_active = not target.is_active
    db.session.commit()
    
    return jsonify({
        'success': True,
        'user_id': target.id,
        'is_active': target.is_active,
        'message': f'User {"activated" if target.is_active else "deactivated"}'
    })


# CONTENT MODERATION

@admin_bp.route('/posts', methods=['GET'])
@token_required
@admin_required
def list_posts(user_id):
    """Get all posts for moderation"""
    page = request.args.get('page', 1, type=int)
    posts = CollxPost.query.order_by(CollxPost.created_at.desc()).paginate(
        page=page, per_page=20, error_out=False
    )
    return jsonify({
        'success': True,
        'count': len(posts.items),
        'total': posts.total,
        'page': page,
        'data': [p.to_dict() for p in posts.items]
    })


@admin_bp.route('/posts/<int:post_id>', methods=['DELETE'])
@token_required
@admin_required
def delete_post(user_id, post_id):
    """Delete a post (admin moderation)"""
    post = db.session.get(CollxPost, post_id)
    if not post:
        return jsonify({'success': False, 'error': 'Post not found'}), 404

    # Delete related data
    CollxLike.query.filter_by(post_id=post_id).delete()
    CollxReply.query.filter_by(post_id=post_id).delete()
    Notification.query.filter_by(post_id=post_id).delete()
    db.session.delete(post)
    db.session.commit()

    return jsonify({'success': True, 'message': f'Post #{post_id} deleted'})


@admin_bp.route('/questions/<int:q_id>', methods=['DELETE'])
@token_required
@admin_required
def delete_question(user_id, q_id):
    """Delete a question (admin moderation)"""
    question = db.session.get(Question, q_id)
    if not question:
        return jsonify({'success': False, 'error': 'Question not found'}), 404

    Answer.query.filter_by(question_id=q_id).delete()
    db.session.delete(question)
    db.session.commit()

    return jsonify({'success': True, 'message': f'Question #{q_id} deleted'})


# SYSTEM OVERVIEW

@admin_bp.route('/overview', methods=['GET'])
@token_required
@admin_required
def system_overview(user_id):
    """Comprehensive system overview for admin"""
    total_users = UserAccount.query.count()
    active_users = UserAccount.query.filter_by(is_active=True).count()
    total_posts = CollxPost.query.count()
    total_replies = CollxReply.query.count()
    total_likes = db.session.query(db.func.sum(CollxPost.like_count)).scalar() or 0
    total_follows = CollxFollow.query.count()
    total_questions = Question.query.count()
    total_answers = Answer.query.count()
    total_dms = DirectMessage.query.count()
    total_notifs = Notification.query.count()
    unread_notifs = Notification.query.filter_by(is_read=False).count()

    # Department breakdown
    dept_stats = db.session.query(
        UserAccount.department, db.func.count(UserAccount.id)
    ).group_by(UserAccount.department).all()

    # Top contributors
    top_users = db.session.query(
        UserAccount.name,
        UserAccount.username,
        UserAccount.profile_color,
        db.func.count(CollxPost.id).label('posts')
    ).join(CollxPost, CollxPost.user_id == UserAccount.id)\
        .group_by(UserAccount.id)\
        .order_by(db.func.count(CollxPost.id).desc())\
        .limit(5).all()

    return jsonify({
        'success': True,
        'data': {
            'users': {
                'total': total_users,
                'active': active_users,
                'inactive': total_users - active_users,
            },
            'content': {
                'posts': total_posts,
                'replies': total_replies,
                'likes': int(total_likes),
                'questions': total_questions,
                'answers': total_answers,
            },
            'social': {
                'follows': total_follows,
                'dms': total_dms,
                'notifications': total_notifs,
                'unread_notifs': unread_notifs,
            },
            'departments': [{'name': d[0], 'count': d[1]} for d in dept_stats],
            'top_contributors': [
                {'name': t[0], 'username': t[1], 'color': t[2], 'posts': t[3]}
                for t in top_users
            ],
        }
    })


@admin_bp.route('/audit-log', methods=['GET'])
@token_required
@admin_required
def audit_log(user_id):
    """Recent platform activity for admin audit"""
    activities = []

    # Recent posts
    recent_posts = CollxPost.query.order_by(CollxPost.created_at.desc()).limit(5).all()
    for p in recent_posts:
        user = db.session.get(UserAccount, p.user_id)
        activities.append({
            'type': 'post',
            'icon': '📝',
            'description': f'{user.name if user else "Unknown"} posted: "{p.content[:50]}..."',
            'time': p.created_at.isoformat() if p.created_at else None,
        })

    # Recent DMs
    recent_dms = DirectMessage.query.order_by(DirectMessage.created_at.desc()).limit(5).all()
    for dm in recent_dms:
        sender = db.session.get(UserAccount, dm.sender_id)
        receiver = db.session.get(UserAccount, dm.receiver_id)
        activities.append({
            'type': 'dm',
            'icon': '✉️',
            'description': f'{sender.name if sender else "?"} → {receiver.name if receiver else "?"}: DM sent',
            'time': dm.created_at.isoformat() if dm.created_at else None,
        })

    # Recent follows
    recent_follows = CollxFollow.query.order_by(CollxFollow.created_at.desc()).limit(5).all()
    for f in recent_follows:
        follower = db.session.get(UserAccount, f.follower_id)
        target = db.session.get(UserAccount, f.following_id)
        activities.append({
            'type': 'follow',
            'icon': '👤',
            'description': f'{follower.name if follower else "?"} followed {target.name if target else "?"}',
            'time': f.created_at.isoformat() if f.created_at else None,
        })

    # Sort all by time
    activities.sort(key=lambda a: a['time'] or '', reverse=True)
    return jsonify({'success': True, 'data': activities[:15]})
