"""
Community Module — Campus-wide broadcast channels
WhatsApp-style community with channels: general, academic, placement, events, sports
"""
from flask import jsonify, request
from . import community_bp
from database.models import db, UserAccount, CommunityPost
from modules.auth.jwt_utils import token_required

CHANNELS = [
    {"id": "general",   "name": "General",    "emoji": "💬", "desc": "Campus-wide chat for all students",    "color": "#3B82F6"},
    {"id": "academic",  "name": "Academic",   "emoji": "📚", "desc": "Study material, notes, exam tips",     "color": "#8B5CF6"},
    {"id": "placement", "name": "Placements", "emoji": "💼", "desc": "Job openings, interviews, prep",       "color": "#10B981"},
    {"id": "events",    "name": "Events",     "emoji": "🎉", "desc": "Fests, workshops, talks, meetups",     "color": "#F59E0B"},
    {"id": "sports",    "name": "Sports",     "emoji": "🏆", "desc": "Cricket, football, gym, tournaments",  "color": "#EF4444"},
]


@community_bp.route('/channels', methods=['GET'])
@token_required
def get_channels(user_id):
    """Get all community channels with latest post"""
    result = []
    for ch in CHANNELS:
        last_post = CommunityPost.query.filter_by(channel=ch['id'])\
            .order_by(CommunityPost.created_at.desc()).first()
        total = CommunityPost.query.filter_by(channel=ch['id']).count()
        d = dict(ch)
        d['total_posts'] = total
        d['last_post'] = last_post.content[:60] if last_post else ''
        d['last_post_author'] = last_post.to_dict()['author_name'] if last_post else ''
        d['last_post_time'] = last_post.created_at.isoformat() if last_post and last_post.created_at else None
        result.append(d)
    return jsonify(result)


@community_bp.route('/<channel>', methods=['GET'])
@token_required
def get_channel_posts(user_id, channel):
    """Get posts in a channel"""
    page = request.args.get('page', 1, type=int)
    posts = CommunityPost.query.filter_by(channel=channel)\
        .order_by(CommunityPost.created_at.desc())\
        .paginate(page=page, per_page=50, error_out=False)

    return jsonify({
        'success': True,
        'channel': channel,
        'posts': [p.to_dict() for p in reversed(posts.items)],
        'has_more': posts.has_next,
    })


@community_bp.route('/<channel>/post', methods=['POST'])
@token_required
def create_post(user_id, channel):
    """Post to a community channel"""
    data = request.json or {}
    content = data.get('content', '').strip()
    if not content or len(content) > 1000:
        return jsonify({'error': 'Content must be 1-1000 chars'}), 400

    valid_channels = [c['id'] for c in CHANNELS]
    if channel not in valid_channels:
        return jsonify({'error': 'Invalid channel'}), 400

    post = CommunityPost(
        channel=channel,
        author_id=user_id,
        content=content,
    )
    db.session.add(post)
    db.session.commit()

    return jsonify({'success': True, 'post': post.to_dict()}), 201
