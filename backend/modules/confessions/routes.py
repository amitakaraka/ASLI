"""
Confessions Module — Anonymous Campus Confessions
Post anonymously, react with emojis, browse by category
"""
from flask import jsonify, request
from . import confessions_bp
from database.models import db, Confession, ConfessionReaction
from modules.auth.jwt_utils import token_required


CATEGORIES = ['general', 'crush', 'academics', 'hostel', 'rant', 'funny']
REACTION_EMOJIS = ['❤️', '😂', '😢', '😮', '🔥', '💀']


@confessions_bp.route('/', methods=['GET'])
@token_required
def get_confessions(user_id):
    """Get all confessions, optionally filtered by category"""
    category = request.args.get('category', None)
    query = Confession.query.filter_by(is_active=True)
    if category and category in CATEGORIES:
        query = query.filter_by(category=category)
    confessions = query.order_by(Confession.created_at.desc()).all()
    return jsonify({
        'confessions': [c.to_dict(user_id=user_id) for c in confessions],
        'categories': CATEGORIES,
        'reaction_emojis': REACTION_EMOJIS,
    })


@confessions_bp.route('/create', methods=['POST'])
@token_required
def create_confession(user_id):
    """Post confession"""
    data = request.json or {}
    content = data.get('content', '').strip()
    category = data.get('category', 'general')
    mood = data.get('mood', '😶')

    if not content:
        return jsonify({'error': 'Content is required'}), 400
    if len(content) > 500:
        return jsonify({'error': 'Max 500 characters'}), 400
    if category not in CATEGORIES:
        category = 'general'

    confession = Confession(
        author_id=user_id,
        content=content,
        category=category,
        mood=mood,
    )
    db.session.add(confession)
    db.session.commit()

    return jsonify({'success': True, 'confession': confession.to_dict(user_id=user_id)})


@confessions_bp.route('/react/<int:confession_id>', methods=['POST'])
@token_required
def react_confession(user_id, confession_id):
    """React to a confession with an emoji"""
    confession = db.session.get(Confession, confession_id)
    if not confession:
        return jsonify({'error': 'Confession not found'}), 404

    data = request.json or {}
    emoji = data.get('emoji', '❤️')
    if emoji not in REACTION_EMOJIS:
        emoji = '❤️'

    existing = ConfessionReaction.query.filter_by(
        confession_id=confession_id, user_id=user_id
    ).first()

    if existing:
        if existing.emoji == emoji:
            # Toggle off — remove reaction
            db.session.delete(existing)
            db.session.commit()
            return jsonify({'success': True, 'action': 'removed', 'confession': confession.to_dict(user_id=user_id)})
        else:
            # Change reaction
            existing.emoji = emoji
            db.session.commit()
            return jsonify({'success': True, 'action': 'changed', 'confession': confession.to_dict(user_id=user_id)})
    else:
        reaction = ConfessionReaction(
            confession_id=confession_id, user_id=user_id, emoji=emoji
        )
        db.session.add(reaction)
        db.session.commit()
        return jsonify({'success': True, 'action': 'added', 'confession': confession.to_dict(user_id=user_id)})


@confessions_bp.route('/trending', methods=['GET'])
@token_required
def trending_confessions(user_id):
    """Get top confessions by reaction count"""
    confessions = Confession.query.filter_by(is_active=True).all()
    # Sort by dynamic reaction count
    sorted_confessions = sorted(confessions, key=lambda c: c.reactions.count(), reverse=True)
    return jsonify({
        'confessions': [c.to_dict(user_id=user_id) for c in sorted_confessions[:20]],
    })
