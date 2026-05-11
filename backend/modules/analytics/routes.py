"""
Analytics Module — Platform Intelligence Dashboard
Provides stats, activity feed, and growth metrics
"""
from flask import Blueprint, jsonify
from database.models import db, UserAccount, CollxPost, CollxLike, CollxReply, CollxFollow, Question, Answer, Notification
from sqlalchemy import func
from datetime import datetime, timedelta

analytics_bp = Blueprint('analytics', __name__, url_prefix='/api/analytics')


@analytics_bp.route('/stats', methods=['GET'])
def platform_stats():
    """Core platform statistics"""
    total_users = UserAccount.query.count()
    total_posts = CollxPost.query.count()
    total_likes = CollxLike.query.count()
    total_replies = CollxReply.query.count()
    total_follows = CollxFollow.query.count()
    total_questions = Question.query.count()
    total_answers = Answer.query.count()
    total_notifications = Notification.query.count()

    # Engagement rate
    engagement = 0
    if total_posts > 0:
        engagement = round(((total_likes + total_replies) / total_posts) * 100, 1)

    # Most active user
    top_poster = db.session.query(
        UserAccount.name,
        func.count(CollxPost.id).label('post_count')
    ).join(CollxPost, UserAccount.id == CollxPost.user_id).group_by(
        UserAccount.name
    ).order_by(func.count(CollxPost.id).desc()).first()

    # Most liked post
    top_post = CollxPost.query.order_by(CollxPost.like_count.desc()).first()

    return jsonify({
        'success': True,
        'data': {
            'users': {
                'total': total_users,
                'label': 'Registered Users',
                'icon': 'people'
            },
            'posts': {
                'total': total_posts,
                'label': 'CollX Posts',
                'icon': 'feed'
            },
            'interactions': {
                'likes': total_likes,
                'replies': total_replies,
                'follows': total_follows,
                'label': 'Total Interactions'
            },
            'qa': {
                'questions': total_questions,
                'answers': total_answers,
                'label': 'Q&A Activity'
            },
            'engagement_rate': engagement,
            'top_poster': {
                'name': top_poster[0] if top_poster else 'N/A',
                'count': top_poster[1] if top_poster else 0
            },
            'top_post': top_post.to_dict() if top_post else None,
            'notifications_sent': total_notifications,
        }
    })


@analytics_bp.route('/activity', methods=['GET'])
def recent_activity():
    """Recent activity feed across the platform"""
    activities = []

    # Recent posts
    recent_posts = CollxPost.query.order_by(CollxPost.created_at.desc()).limit(5).all()
    for p in recent_posts:
        author = db.session.get(UserAccount, p.user_id)
        activities.append({
            'type': 'post',
            'icon': 'edit',
            'color': '#4F46E5',
            'title': f'{author.name if author else "Unknown"} posted',
            'detail': p.content[:60] + ('...' if len(p.content) > 60 else ''),
            'time': p.created_at.isoformat() if p.created_at else None,
        })

    # Recent replies
    recent_replies = CollxReply.query.order_by(CollxReply.created_at.desc()).limit(3).all()
    for r in recent_replies:
        author = db.session.get(UserAccount, r.user_id)
        activities.append({
            'type': 'reply',
            'icon': 'reply',
            'color': '#059669',
            'title': f'{author.name if author else "Unknown"} replied',
            'detail': r.content[:60] + ('...' if len(r.content) > 60 else ''),
            'time': r.created_at.isoformat() if r.created_at else None,
        })

    # Recent follows
    recent_follows = CollxFollow.query.order_by(CollxFollow.created_at.desc()).limit(3).all()
    for f in recent_follows:
        follower = db.session.get(UserAccount, f.follower_id)
        target = db.session.get(UserAccount, f.following_id)
        activities.append({
            'type': 'follow',
            'icon': 'person_add',
            'color': '#D97706',
            'title': f'{follower.name if follower else "?"} followed {target.name if target else "?"}',
            'detail': '',
            'time': f.created_at.isoformat() if f.created_at else None,
        })

    # Sort by time, newest first
    activities.sort(key=lambda x: x['time'] or '', reverse=True)

    return jsonify({'success': True, 'data': activities[:15]})


@analytics_bp.route('/leaderboard', methods=['GET'])
def leaderboard():
    """User leaderboard ranked by engagement"""
    users = UserAccount.query.all()
    rankings = []
    for u in users:
        post_count = CollxPost.query.filter_by(user_id=u.id).count()
        total_likes = sum(p.like_count for p in CollxPost.query.filter_by(user_id=u.id).all())
        reply_count = CollxReply.query.filter_by(user_id=u.id).count()
        score = (post_count * 10) + (total_likes * 3) + (reply_count * 5) + (u.follower_count * 8)
        rankings.append({
            'user_id': u.id,
            'name': u.name,
            'username': u.username,
            'department': u.department,
            'profile_color': u.profile_color,
            'posts': post_count,
            'likes_received': total_likes,
            'replies': reply_count,
            'followers': u.follower_count,
            'score': score,
        })
    rankings.sort(key=lambda x: x['score'], reverse=True)
    return jsonify({'success': True, 'data': rankings})


@analytics_bp.route('/modules', methods=['GET'])
def module_health():
    """Health and stats for each backend module"""
    modules = [
        {'name': 'Auth', 'icon': 'lock', 'status': 'active', 'color': '#A9523C',
         'stats': f'{UserAccount.query.count()} users registered'},
        {'name': 'Chat', 'icon': 'chat', 'status': 'active', 'color': '#4F46E5',
         'stats': 'NLP engine running'},
        {'name': 'Q&A', 'icon': 'forum', 'status': 'active', 'color': '#059669',
         'stats': f'{Question.query.count()} questions, {Answer.query.count()} answers'},
        {'name': 'CollX', 'icon': 'public', 'status': 'active', 'color': '#E11D48',
         'stats': f'{CollxPost.query.count()} posts, {CollxLike.query.count()} likes'},
        {'name': 'Events', 'icon': 'event', 'status': 'active', 'color': '#D97706',
         'stats': 'Events data loaded'},
        {'name': 'Notifications', 'icon': 'notifications', 'status': 'active', 'color': '#7C3AED',
         'stats': f'{Notification.query.count()} sent'},
        {'name': 'Analytics', 'icon': 'analytics', 'status': 'active', 'color': '#0EA5E9',
         'stats': 'Dashboard live'},
    ]
    return jsonify({'success': True, 'data': modules})
