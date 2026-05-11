"""
Notifications Module Routes — In-App Notification System
"""
from flask import Blueprint, request, jsonify
from database.models import db, Notification
from modules.auth.jwt_utils import token_required

notif_bp = Blueprint('notifications', __name__, url_prefix='/api/notifications')


@notif_bp.route('', methods=['GET'])
@token_required
def get_notifications(user_id):
    """Get user's notifications (newest first)"""
    page = request.args.get('page', 1, type=int)
    notifications = Notification.query.filter_by(user_id=user_id).order_by(
        Notification.created_at.desc()
    ).paginate(page=page, per_page=30, error_out=False)

    unread = Notification.query.filter_by(user_id=user_id, is_read=False).count()

    return jsonify({
        'success': True,
        'count': len(notifications.items),
        'unread_count': unread,
        'data': [n.to_dict() for n in notifications.items]
    })


@notif_bp.route('/unread-count', methods=['GET'])
@token_required
def unread_count(user_id):
    """Get count of unread notifications"""
    count = Notification.query.filter_by(user_id=user_id, is_read=False).count()
    return jsonify({'success': True, 'count': count})


@notif_bp.route('/read-all', methods=['POST'])
@token_required
def mark_all_read(user_id):
    """Mark all read"""
    Notification.query.filter_by(user_id=user_id, is_read=False).update({'is_read': True})
    db.session.commit()
    return jsonify({'success': True, 'message': 'All notifications marked as read'})


@notif_bp.route('/<int:notif_id>/read', methods=['POST'])
@token_required
def mark_read(user_id, notif_id):
    """Mark a single notification as read"""
    notif = Notification.query.filter_by(id=notif_id, user_id=user_id).first()
    if not notif:
        return jsonify({'success': False, 'error': 'Notification not found'}), 404
    notif.is_read = True
    db.session.commit()
    return jsonify({'success': True})
