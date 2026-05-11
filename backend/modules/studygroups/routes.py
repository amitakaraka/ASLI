"""
Study Groups Module — Campus Collaboration + Group Chat
Create, join, leave study groups. Send/receive group messages.
"""
from flask import jsonify, request
from . import studygroups_bp
from database.models import db, UserAccount, StudyGroup, StudyGroupMember, GroupMessage
from modules.auth.jwt_utils import token_required
from sqlalchemy import and_


# GROUP LISTING

@studygroups_bp.route('/', methods=['GET'])
@token_required
def get_groups(user_id):
    """Get all active study groups"""
    groups = StudyGroup.query.filter_by(is_active=True).order_by(StudyGroup.created_at.desc()).all()
    result = []
    for g in groups:
        d = g.to_dict(user_id=user_id)
        last_msg = GroupMessage.query.filter_by(group_id=g.id).order_by(GroupMessage.created_at.desc()).first()
        if last_msg:
            d['last_message'] = last_msg.content[:60]
            d['last_message_sender'] = last_msg.to_dict()['sender_name']
            d['last_message_time'] = last_msg.created_at.isoformat() if last_msg.created_at else None
        result.append(d)
    return jsonify(result)


@studygroups_bp.route('/my', methods=['GET'])
@token_required
def my_groups(user_id):
    """Get groups the current user belongs to"""
    memberships = StudyGroupMember.query.filter_by(user_id=user_id).all()
    groups = []
    for m in memberships:
        group = db.session.get(StudyGroup, m.group_id)
        if group and group.is_active:
            d = group.to_dict(user_id=user_id)
            last_msg = GroupMessage.query.filter_by(group_id=group.id).order_by(GroupMessage.created_at.desc()).first()
            d['last_message'] = last_msg.content[:60] if last_msg else ''
            d['last_message_sender'] = last_msg.to_dict()['sender_name'] if last_msg else ''
            d['last_message_time'] = last_msg.created_at.isoformat() if last_msg and last_msg.created_at else None
            groups.append(d)
    groups.sort(key=lambda g: g.get('last_message_time') or '', reverse=True)
    return jsonify(groups)


# GROUP CRUD

@studygroups_bp.route('/create', methods=['POST'])
@token_required
def create_group(user_id):
    """Create group"""
    data = request.json or {}
    name = data.get('name', '').strip()
    subject = data.get('subject', '').strip()
    description = data.get('description', '').strip()
    emoji = data.get('emoji', '📚')
    color = data.get('color', '#3B82F6')
    max_members = data.get('max_members', 20)

    if not name or not subject:
        return jsonify({'error': 'Name and subject required'}), 400

    group = StudyGroup(
        name=name,
        subject=subject,
        description=description,
        emoji=emoji,
        color=color,
        max_members=max_members,
        creator_id=user_id,
    )
    db.session.add(group)
    db.session.flush()

    # Creator auto-joins as admin
    member = StudyGroupMember(group_id=group.id, user_id=user_id, role='admin')
    db.session.add(member)

    # System message
    creator = db.session.get(UserAccount, user_id)
    sys_msg = GroupMessage(
        group_id=group.id,
        sender_id=user_id,
        content=f'{creator.name if creator else "Someone"} created the group "{name}"',
        message_type='system',
    )
    db.session.add(sys_msg)
    db.session.commit()

    return jsonify({'success': True, 'group': group.to_dict(user_id=user_id)})


@studygroups_bp.route('/join/<int:group_id>', methods=['POST'])
@token_required
def join_group(user_id, group_id):
    """Join group"""
    group = db.session.get(StudyGroup, group_id)
    if not group:
        return jsonify({'error': 'Group not found'}), 404

    existing = StudyGroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
    if existing:
        return jsonify({'error': 'Already a member'}), 400

    if group.members.count() >= group.max_members:
        return jsonify({'error': 'Group is full'}), 400

    member = StudyGroupMember(group_id=group_id, user_id=user_id, role='member')
    db.session.add(member)

    joiner = db.session.get(UserAccount, user_id)
    sys_msg = GroupMessage(
        group_id=group_id,
        sender_id=user_id,
        content=f'{joiner.name if joiner else "Someone"} joined the group',
        message_type='system',
    )
    db.session.add(sys_msg)
    db.session.commit()

    return jsonify({'success': True, 'group': group.to_dict(user_id=user_id)})


@studygroups_bp.route('/leave/<int:group_id>', methods=['POST'])
@token_required
def leave_group(user_id, group_id):
    """Leave a study group"""
    membership = StudyGroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
    if not membership:
        return jsonify({'error': 'Not a member'}), 400

    leaver = db.session.get(UserAccount, user_id)
    db.session.delete(membership)

    sys_msg = GroupMessage(
        group_id=group_id,
        sender_id=user_id,
        content=f'{leaver.name if leaver else "Someone"} left the group',
        message_type='system',
    )
    db.session.add(sys_msg)
    db.session.commit()

    group = db.session.get(StudyGroup, group_id)
    return jsonify({'success': True, 'group': group.to_dict(user_id=user_id) if group else {}})


@studygroups_bp.route('/<int:group_id>', methods=['GET'])
@token_required
def get_group_detail(user_id, group_id):
    """Get group details with member list"""
    group = db.session.get(StudyGroup, group_id)
    if not group:
        return jsonify({'error': 'Group not found'}), 404

    memberships = StudyGroupMember.query.filter_by(group_id=group_id).order_by(StudyGroupMember.joined_at).all()
    members = []
    for m in memberships:
        user = db.session.get(UserAccount, m.user_id)
        if user:
            members.append({
                'user_id': user.id,
                'name': user.name,
                'username': user.username,
                'profile_color': user.profile_color,
                'department': user.department,
                'role': m.role,
                'joined_at': m.joined_at.isoformat() if m.joined_at else None,
            })

    result = group.to_dict(user_id=user_id)
    result['members'] = members
    return jsonify(result)


# GROUP CHAT MESSAGES

@studygroups_bp.route('/<int:group_id>/messages', methods=['GET'])
@token_required
def get_group_messages(user_id, group_id):
    """Get message history for a group"""
    group = db.session.get(StudyGroup, group_id)
    if not group:
        return jsonify({'error': 'Group not found'}), 404

    is_member = StudyGroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
    if not is_member:
        return jsonify({'error': 'Not a member'}), 403

    page = request.args.get('page', 1, type=int)
    messages = GroupMessage.query.filter_by(group_id=group_id)\
        .order_by(GroupMessage.created_at.desc())\
        .paginate(page=page, per_page=50, error_out=False)

    return jsonify({
        'success': True,
        'group': group.to_dict(user_id=user_id),
        'messages': [m.to_dict() for m in reversed(messages.items)],
        'has_more': messages.has_next,
    })


@studygroups_bp.route('/<int:group_id>/send', methods=['POST'])
@token_required
def send_group_message(user_id, group_id):
    """Send a message to a group"""
    group = db.session.get(StudyGroup, group_id)
    if not group:
        return jsonify({'error': 'Group not found'}), 404

    is_member = StudyGroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
    if not is_member:
        return jsonify({'error': 'Not a member'}), 403

    data = request.json or {}
    content = data.get('content', '').strip()
    if not content or len(content) > 1000:
        return jsonify({'error': 'Message must be 1-1000 chars'}), 400

    msg = GroupMessage(
        group_id=group_id,
        sender_id=user_id,
        content=content,
        message_type='text',
    )
    db.session.add(msg)
    db.session.commit()

    return jsonify({'success': True, 'message': msg.to_dict()}), 201
