"""
Bookmarks Module — Save & Manage Bookmarked Posts
"""
from flask import Blueprint, request, jsonify
from database.models import db, Bookmark, CollxPost, UserAccount
from modules.auth.jwt_utils import token_required

bookmarks_bp = Blueprint('bookmarks', __name__, url_prefix='/api/bookmarks')


@bookmarks_bp.route('/', methods=['GET'])
@token_required
def get_bookmarks(user_id):
    """Get all bookmarked posts for current user"""
    bookmarks = Bookmark.query.filter_by(user_id=user_id)\
        .order_by(Bookmark.created_at.desc()).all()
    return jsonify({
        'success': True,
        'count': len(bookmarks),
        'data': [b.to_dict() for b in bookmarks]
    })


@bookmarks_bp.route('/toggle', methods=['POST'])
@token_required
def toggle_bookmark(user_id):
    """Toggle bookmark on a post"""
    data = request.json
    if not data or 'post_id' not in data:
        return jsonify({'success': False, 'error': 'post_id required'}), 400

    post_id = data['post_id']
    post = db.session.get(CollxPost, post_id)
    if not post:
        return jsonify({'success': False, 'error': 'Post not found'}), 404

    existing = Bookmark.query.filter_by(user_id=user_id, post_id=post_id).first()
    if existing:
        db.session.delete(existing)
        db.session.commit()
        return jsonify({'success': True, 'bookmarked': False, 'message': 'Bookmark removed'})
    else:
        bookmark = Bookmark(user_id=user_id, post_id=post_id)
        db.session.add(bookmark)
        db.session.commit()
        return jsonify({'success': True, 'bookmarked': True, 'message': 'Post bookmarked'})


@bookmarks_bp.route('/check/<int:post_id>', methods=['GET'])
@token_required
def check_bookmark(user_id, post_id):
    """Check if a post is bookmarked"""
    exists = Bookmark.query.filter_by(user_id=user_id, post_id=post_id).first()
    return jsonify({'success': True, 'bookmarked': exists is not None})


@bookmarks_bp.route('/count', methods=['GET'])
@token_required
def bookmark_count(user_id):
    """Get total bookmark count"""
    count = Bookmark.query.filter_by(user_id=user_id).count()
    return jsonify({'success': True, 'count': count})
