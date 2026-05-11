"""
Messages Module — Direct Messaging System
Private user-to-user chat
"""
from flask import Blueprint, request, jsonify
from database.models import db, DirectMessage, UserAccount
from modules.auth.jwt_utils import token_required
from services.notification_service import notify_dm
from sqlalchemy import or_, and_, func

messages_bp = Blueprint('messages', __name__, url_prefix='/api/messages')


@messages_bp.route('/conversations', methods=['GET'])
@token_required
def get_conversations(user_id):
    """Get list of conversations (unique users you've messaged with)"""
    # Find all unique users this user has messaged with
    sent = db.session.query(DirectMessage.receiver_id).filter_by(sender_id=user_id).distinct()
    received = db.session.query(DirectMessage.sender_id).filter_by(receiver_id=user_id).distinct()

    partner_ids = set()
    for row in sent.all():
        partner_ids.add(row[0])
    for row in received.all():
        partner_ids.add(row[0])

    conversations = []
    for pid in partner_ids:
        partner = db.session.get(UserAccount, pid)
        if not partner:
            continue

        # Get last message
        last_msg = DirectMessage.query.filter(
            or_(
                and_(DirectMessage.sender_id == user_id, DirectMessage.receiver_id == pid),
                and_(DirectMessage.sender_id == pid, DirectMessage.receiver_id == user_id),
            )
        ).order_by(DirectMessage.created_at.desc()).first()

        # Unread count
        unread = DirectMessage.query.filter_by(
            sender_id=pid, receiver_id=user_id, is_read=False
        ).count()

        conversations.append({
            'partner_id': pid,
            'partner_name': partner.name,
            'partner_username': partner.username,
            'partner_color': partner.profile_color,
            'last_message': last_msg.content[:60] if last_msg else '',
            'last_time': last_msg.created_at.isoformat() if last_msg and last_msg.created_at else None,
            'unread_count': unread,
            'is_sender': last_msg.sender_id == user_id if last_msg else False,
        })

    # Sort by last message time
    conversations.sort(key=lambda c: c['last_time'] or '', reverse=True)
    return jsonify({'success': True, 'data': conversations})


@messages_bp.route('/chat/<int:partner_id>', methods=['GET'])
@token_required
def get_chat(user_id, partner_id):
    """Get messages between two users"""
    page = request.args.get('page', 1, type=int)
    messages = DirectMessage.query.filter(
        or_(
            and_(DirectMessage.sender_id == user_id, DirectMessage.receiver_id == partner_id),
            and_(DirectMessage.sender_id == partner_id, DirectMessage.receiver_id == user_id),
        )
    ).order_by(DirectMessage.created_at.desc()).paginate(page=page, per_page=50, error_out=False)

    # Mark received messages as read
    DirectMessage.query.filter_by(
        sender_id=partner_id, receiver_id=user_id, is_read=False
    ).update({'is_read': True})
    db.session.commit()

    partner = db.session.get(UserAccount, partner_id)
    return jsonify({
        'success': True,
        'partner': partner.to_public_dict() if partner else None,
        'messages': [m.to_dict() for m in reversed(messages.items)],
        'has_more': messages.has_next,
    })


@messages_bp.route('/send', methods=['POST'])
@token_required
def send_message(user_id):
    """Send DM"""
    data = request.json
    if not data or 'receiver_id' not in data or 'content' not in data:
        return jsonify({'success': False, 'error': 'receiver_id and content required'}), 400

    content = data['content'].strip()
    if not content or len(content) > 1000:
        return jsonify({'success': False, 'error': 'Message must be 1-1000 chars'}), 400

    receiver = db.session.get(UserAccount, data['receiver_id'])
    if not receiver:
        return jsonify({'success': False, 'error': 'User not found'}), 404

    msg = DirectMessage(
        sender_id=user_id,
        receiver_id=data['receiver_id'],
        content=content
    )
    db.session.add(msg)
    db.session.commit()
    # Notify receiver
    notify_dm(user_id, data['receiver_id'], content)

    return jsonify({'success': True, 'data': msg.to_dict()}), 201


@messages_bp.route('/unread-total', methods=['GET'])
@token_required
def unread_total(user_id):
    """Get total unread DM count"""
    count = DirectMessage.query.filter_by(receiver_id=user_id, is_read=False).count()
    return jsonify({'success': True, 'count': count})
