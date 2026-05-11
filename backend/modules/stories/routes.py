"""
Stories Module — Ephemeral Campus Stories (24h auto-expiry)
"""
from flask import request, jsonify
from . import stories_bp
from database.models import db, Story, StoryView
from modules.auth.jwt_utils import token_required
from datetime import datetime, timedelta
from utils.time import utc_now


@stories_bp.route('/', methods=['GET'])
@token_required
def get_stories(user_id):
    """Get all active (non-expired) stories, grouped by creator"""
    now = utc_now()
    stories = Story.query.filter(Story.expires_at > now)\
        .order_by(Story.created_at.desc()).all()

    # Group stories by creator
    creators = {}
    for s in stories:
        cid = s.creator_id
        sd = s.to_dict(user_id=user_id)
        if cid not in creators:
            creators[cid] = {
                "creator_id": cid,
                "creator_name": sd['creator_name'],
                "creator_username": sd['creator_username'],
                "creator_color": sd['creator_color'],
                "stories": [],
                "has_unseen": False,
            }
        creators[cid]['stories'].append(sd)
        if not sd['viewed']:
            creators[cid]['has_unseen'] = True

    return jsonify(list(creators.values()))


@stories_bp.route('/create', methods=['POST'])
@token_required
def create_story(user_id):
    """Create a new story (expires in 24h)"""
    data = request.get_json()
    text = data.get('text', '').strip()
    bg_color = data.get('bg_color', '#A9523C')
    emoji = data.get('emoji', '')

    if not text:
        return jsonify({"error": "Story text is required"}), 400

    story = Story(
        creator_id=user_id,
        text=text,
        bg_color=bg_color,
        emoji=emoji,
        expires_at=utc_now() + timedelta(hours=24),
    )
    db.session.add(story)
    db.session.commit()
    return jsonify({"message": "Story posted!", "story": story.to_dict(user_id=user_id)})


@stories_bp.route('/view/<int:story_id>', methods=['POST'])
@token_required
def view_story(user_id, story_id):
    """Mark a story as viewed by the current user"""
    story = db.session.get(Story, story_id)
    if not story:
        return jsonify({"error": "Story not found"}), 404

    existing = StoryView.query.filter_by(story_id=story_id, user_id=user_id).first()
    if not existing:
        view = StoryView(story_id=story_id, user_id=user_id)
        db.session.add(view)
        db.session.commit()

    return jsonify({"message": "Viewed", "story": story.to_dict(user_id=user_id)})


@stories_bp.route('/my', methods=['GET'])
@token_required
def my_stories(user_id):
    """Get current user's active stories with view counts"""
    now = utc_now()
    stories = Story.query.filter_by(creator_id=user_id)\
        .filter(Story.expires_at > now)\
        .order_by(Story.created_at.desc()).all()
    return jsonify([s.to_dict(user_id=user_id) for s in stories])
