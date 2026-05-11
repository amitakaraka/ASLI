"""
Polls Module — Interactive Polls & Voting
"""
from flask import request, jsonify
from . import polls_bp
from database.models import db, Poll, PollOption, PollVote
from modules.auth.jwt_utils import token_required
from datetime import datetime, timedelta
from utils.time import utc_now


@polls_bp.route('/', methods=['GET'])
@token_required
def get_polls(user_id):
    """Get polls"""
    polls = Poll.query.order_by(Poll.created_at.desc()).all()
    return jsonify([p.to_dict(user_id=user_id) for p in polls])


@polls_bp.route('/create', methods=['POST'])
@token_required
def create_poll(user_id):
    """Create a new poll with 2-4 options"""
    data = request.get_json()
    question = data.get('question', '').strip()
    options = data.get('options', [])
    duration_hours = data.get('duration_hours', 24)

    if not question or len(options) < 2:
        return jsonify({"error": "Poll needs a question and at least 2 options"}), 400

    if len(options) > 4:
        return jsonify({"error": "Maximum 4 options allowed"}), 400

    poll = Poll(
        question=question,
        creator_id=user_id,
        expires_at=utc_now() + timedelta(hours=duration_hours) if duration_hours else None,
    )
    db.session.add(poll)
    db.session.flush()

    for opt_text in options:
        opt = PollOption(poll_id=poll.id, text=opt_text.strip())
        db.session.add(opt)

    db.session.commit()
    return jsonify({"message": "Poll created!", "poll": poll.to_dict(user_id=user_id)})


@polls_bp.route('/vote', methods=['POST'])
@token_required
def vote_poll(user_id):
    """Vote on poll"""
    data = request.get_json()
    poll_id = data.get('poll_id')
    option_id = data.get('option_id')

    poll = db.session.get(Poll, poll_id)
    if not poll:
        return jsonify({"error": "Poll not found"}), 404

    option = db.session.get(PollOption, option_id)
    if not option or option.poll_id != poll_id:
        return jsonify({"error": "Invalid option"}), 400

    # Check if already voted — allow changing vote
    existing = PollVote.query.filter_by(poll_id=poll_id, user_id=user_id).first()
    if existing:
        existing.option_id = option_id
    else:
        vote = PollVote(poll_id=poll_id, option_id=option_id, user_id=user_id)
        db.session.add(vote)

    db.session.commit()
    return jsonify({"message": "Vote recorded!", "poll": poll.to_dict(user_id=user_id)})


@polls_bp.route('/<int:poll_id>', methods=['GET'])
@token_required
def get_poll(user_id, poll_id):
    """Get a specific poll with results"""
    poll = db.session.get(Poll, poll_id)
    if not poll:
        return jsonify({"error": "Poll not found"}), 404
    return jsonify(poll.to_dict(user_id=user_id))
