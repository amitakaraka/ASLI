"""
Leaderboard Module — Campus Engagement Rankings
Computes scores from posts, replies, likes, polls, stories, and events
"""
from flask import jsonify
from . import leaderboard_bp
from database.models import db, UserAccount, CollxPost, CollxReply, CollxLike, PollVote, Story
from modules.auth.jwt_utils import token_required
from sqlalchemy import func


# Point values for different actions
POINTS = {
    'post': 10,
    'reply': 5,
    'like_given': 2,
    'like_received': 3,
    'poll_vote': 2,
    'story': 8,
}

BADGES = [
    {'min': 0,   'rank': 'Newcomer',   'emoji': '🌱', 'color': '#94A3B8'},
    {'min': 20,  'rank': 'Active',     'emoji': '⚡', 'color': '#3B82F6'},
    {'min': 50,  'rank': 'Contributor','emoji': '🔥', 'color': '#F59E0B'},
    {'min': 100, 'rank': 'Star',       'emoji': '⭐', 'color': '#EF4444'},
    {'min': 200, 'rank': 'Legend',     'emoji': '👑', 'color': '#8B5CF6'},
    {'min': 500, 'rank': 'Campus Icon','emoji': '🏆', 'color': '#10B981'},
]


def _get_badge(points):
    badge = BADGES[0]
    for b in BADGES:
        if points >= b['min']:
            badge = b
    return badge


def _calc_scores():
    """Calculate engagement scores for all users"""
    users = UserAccount.query.all()
    scores = []

    for user in users:
        post_count = CollxPost.query.filter_by(user_id=user.id).count()
        reply_count = CollxReply.query.filter_by(user_id=user.id).count()
        likes_given = CollxLike.query.filter_by(user_id=user.id).count()
        likes_received = db.session.query(func.count(CollxLike.id))\
            .join(CollxPost, CollxLike.post_id == CollxPost.id)\
            .filter(CollxPost.user_id == user.id).scalar() or 0
        poll_votes = PollVote.query.filter_by(user_id=user.id).count()
        story_count = Story.query.filter_by(creator_id=user.id).count()

        total = (
            post_count * POINTS['post'] +
            reply_count * POINTS['reply'] +
            likes_given * POINTS['like_given'] +
            likes_received * POINTS['like_received'] +
            poll_votes * POINTS['poll_vote'] +
            story_count * POINTS['story']
        )
        badge = _get_badge(total)

        scores.append({
            'user_id': user.id,
            'name': user.name,
            'username': user.username,
            'profile_color': user.profile_color,
            'department': user.department,
            'points': total,
            'breakdown': {
                'posts': post_count,
                'replies': reply_count,
                'likes_given': likes_given,
                'likes_received': likes_received,
                'poll_votes': poll_votes,
                'stories': story_count,
            },
            'rank': badge['rank'],
            'rank_emoji': badge['emoji'],
            'rank_color': badge['color'],
        })

    scores.sort(key=lambda x: x['points'], reverse=True)
    for i, s in enumerate(scores):
        s['position'] = i + 1
    return scores


@leaderboard_bp.route('/', methods=['GET'])
@token_required
def get_leaderboard(user_id):
    """Get full leaderboard sorted by points"""
    scores = _calc_scores()
    my_entry = next((s for s in scores if s['user_id'] == user_id), None)
    return jsonify({
        'leaderboard': scores,
        'my_rank': my_entry,
        'point_rules': POINTS,
        'badges': BADGES,
    })
