"""
CollX Module Routes - Enhanced Production Version
Campus Social Network with proper error handling, validation, and pagination
"""
from flask import Blueprint, request, jsonify, g
from database.models import db, UserAccount, CollxPost, CollxLike, CollxReply, CollxFollow
from modules.auth.jwt_utils import token_required, optional_token
from services.notification_service import notify_like, notify_reply, notify_follow
import re
import logging
from utils.time import utc_now

logger = logging.getLogger(__name__)

collx_bp = Blueprint('collx', __name__, url_prefix='/api/collx')


# VALIDATION HELPERS

def validate_post_content(content):
    """Validate post content"""
    if not content or not isinstance(content, str):
        return False, "Content is required"
    if len(content.strip()) < 1:
        return False, "Content cannot be empty"
    if len(content) > 280:
        return False, "Content exceeds 280 characters"
    return True, None


def extract_hashtags(content):
    """Extract hashtags from content"""
    return re.findall(r'#\w+', content)


# FEED ENDPOINTS

@collx_bp.route('/feed', methods=['GET'])
@optional_token
def feed(user_id):
    """
    Get ranked CollX feed with pagination
    
    Query Parameters:
        - page: Page number (default: 1)
        - limit: Posts per page (default: 20, max: 50)
        - hashtag: Filter by hashtag (optional)
    
    Returns paginated posts ranked by engagement
    """
    try:
        page = request.args.get('page', 1, type=int)
        limit = min(request.args.get('limit', 20, type=int), 50)
        hashtag = request.args.get('hashtag', None)
        
        # Validate pagination
        if page < 1:
            page = 1
        if limit < 1:
            limit = 1
        
        # Build query
        query = CollxPost.query
        
        # Filter by hashtag if provided
        if hashtag:
            hashtag = hashtag.strip()
            if not hashtag.startswith('#'):
                hashtag = '#' + hashtag
            query = query.filter(CollxPost.hashtags.like(f'%{hashtag}%'))
        
        # Get posts with engagement-based ranking
        # Score = likes*3 + replies*4 + reposts*5
        posts = query.order_by(
            (CollxPost.like_count * 3 + 
             CollxPost.reply_count * 4 + 
             CollxPost.repost_count * 5).desc(),
            CollxPost.created_at.desc()
        ).paginate(page=page, per_page=limit, error_out=False)
        
        # Convert to dict with bookmark status
        posts_data = []
        for post in posts.items:
            post_dict = post.to_dict()
            if user_id:
                # Check if user liked this post
                like = CollxLike.query.filter_by(user_id=user_id, post_id=post.id).first()
                post_dict['is_liked'] = like is not None
            else:
                post_dict['is_liked'] = False
            posts_data.append(post_dict)
        
        return jsonify({
            'success': True,
            'count': len(posts.items),
            'page': page,
            'limit': limit,
            'total_pages': posts.pages,
            'has_next': posts.has_next,
            'has_prev': posts.has_prev,
            'data': posts_data
        })
    
    except Exception as e:
        logger.error(f"Feed error: {str(e)}", exc_info=True)
        return jsonify({
            'success': False,
            'error': 'Failed to fetch feed',
            'error_code': 'FEED_FETCH_ERROR'
        }), 500


@collx_bp.route('/feed/trending', methods=['GET'])
@optional_token
def trending_feed(user_id):
    """
    Get trending posts (high engagement in recent time)
    
    Returns posts with highest engagement in last 24 hours
    """
    try:
        from datetime import datetime, timedelta
        cutoff = utc_now() - timedelta(hours=24)
        
        posts = CollxPost.query.filter(
            CollxPost.created_at >= cutoff
        ).order_by(
            (CollxPost.like_count * 3 + 
             CollxPost.reply_count * 4 + 
             CollxPost.repost_count * 5).desc()
        ).limit(20).all()
        
        return jsonify({
            'success': True,
            'count': len(posts),
            'data': [p.to_dict() for p in posts]
        })
    
    except Exception as e:
        logger.error(f"Trending feed error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to fetch trending posts',
            'error_code': 'TRENDING_FETCH_ERROR'
        }), 500


# POST CRUD ENDPOINTS

@collx_bp.route('/posts', methods=['POST'])
@token_required
def create_post(user_id):
    """
    Create a new CollX post
    
    Required fields:
        - content: Post content (max 280 chars)
    
    Optional fields:
        - image_url: URL to attached image
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': 'Request body required',
                'error_code': 'VALIDATION_EMPTY_BODY'
            }), 400
        
        content = data.get('content', '').strip()
        image_url = data.get('image_url', '').strip()
        
        # Validate content
        is_valid, error_msg = validate_post_content(content)
        if not is_valid:
            return jsonify({
                'success': False,
                'error': error_msg,
                'error_code': 'VALIDATION_FAILED'
            }), 400
        
        # Extract hashtags
        hashtags = extract_hashtags(content)
        
        # Create post
        post = CollxPost(
            user_id=user_id,
            content=content,
            image_url=image_url if image_url else None,
            hashtags=','.join(hashtags) if hashtags else ''
        )
        
        db.session.add(post)
        
        # Update user post count
        user = db.session.get(UserAccount, user_id)
        if user:
            user.post_count = user.post_count + 1
        
        db.session.commit()
        
        logger.info(f"Post created by user {user_id}: {post.id}")
        
        return jsonify({
            'success': True,
            'message': 'Post created successfully',
            'data': post.to_dict()
        }), 201
    
    except Exception as e:
        logger.error(f"Create post error: {str(e)}", exc_info=True)
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Failed to create post',
            'error_code': 'POST_CREATE_ERROR'
        }), 500


@collx_bp.route('/posts/<int:post_id>', methods=['GET'])
@optional_token
def get_post(user_id, post_id):
    """
    Get a single post with replies
    
    Path parameters:
        - post_id: Post ID
    """
    try:
        post = db.session.get(CollxPost, post_id)
        
        if not post:
            return jsonify({
                'success': False,
                'error': 'Post not found',
                'error_code': 'POST_NOT_FOUND'
            }), 404
        
        # Get replies
        replies = CollxReply.query.filter_by(
            post_id=post_id
        ).order_by(CollxReply.created_at.asc()).limit(50).all()
        
        post_dict = post.to_dict()
        
        # Add like status
        if user_id:
            like = CollxLike.query.filter_by(user_id=user_id, post_id=post_id).first()
            post_dict['is_liked'] = like is not None
        else:
            post_dict['is_liked'] = False
        
        return jsonify({
            'success': True,
            'data': post_dict,
            'replies': [r.to_dict() for r in replies]
        })
    
    except Exception as e:
        logger.error(f"Get post error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to fetch post',
            'error_code': 'POST_FETCH_ERROR'
        }), 500


@collx_bp.route('/posts/<int:post_id>', methods=['DELETE'])
@token_required
def delete_post(user_id, post_id):
    """
    Delete a post (only by author or admin)
    
    Path parameters:
        - post_id: Post ID
    """
    try:
        post = db.session.get(CollxPost, post_id)
        
        if not post:
            return jsonify({
                'success': False,
                'error': 'Post not found',
                'error_code': 'POST_NOT_FOUND'
            }), 404
        
        # Check authorization
        user = db.session.get(UserAccount, user_id)
        if post.user_id != user_id and not (user and user.is_admin):
            return jsonify({
                'success': False,
                'error': 'Unauthorized to delete this post',
                'error_code': 'AUTH_UNAUTHORIZED'
            }), 403
        
        # Delete post
        db.session.delete(post)
        db.session.commit()
        
        logger.info(f"Post deleted: {post_id} by user {user_id}")
        
        return jsonify({
            'success': True,
            'message': 'Post deleted successfully'
        })
    
    except Exception as e:
        logger.error(f"Delete post error: {str(e)}", exc_info=True)
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Failed to delete post',
            'error_code': 'POST_DELETE_ERROR'
        }), 500


# LIKE ENDPOINTS

@collx_bp.route('/posts/<int:post_id>/like', methods=['POST'])
@token_required
def like_post(user_id, post_id):
    """
    Toggle like on a post
    
    Path parameters:
        - post_id: Post ID
    """
    try:
        post = db.session.get(CollxPost, post_id)
        
        if not post:
            return jsonify({
                'success': False,
                'error': 'Post not found',
                'error_code': 'POST_NOT_FOUND'
            }), 404
        
        # Check if already liked
        existing = CollxLike.query.filter_by(
            user_id=user_id, 
            post_id=post_id
        ).first()
        
        if existing:
            # Unlike
            db.session.delete(existing)
            post.like_count = max(0, post.like_count - 1)
            liked = False
        else:
            # Like
            db.session.add(CollxLike(user_id=user_id, post_id=post_id))
            post.like_count += 1
            liked = True
            
            # Send notification
            if post.user_id != user_id:
                notify_like(user_id, post.user_id, post_id)
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'liked': liked,
            'like_count': post.like_count
        })
    
    except Exception as e:
        logger.error(f"Like post error: {str(e)}", exc_info=True)
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Failed to toggle like',
            'error_code': 'LIKE_TOGGLE_ERROR'
        }), 500


# REPLY ENDPOINTS

@collx_bp.route('/posts/<int:post_id>/reply', methods=['POST'])
@token_required
def reply_post(user_id, post_id):
    """
    Reply to a post

    Path parameters:
        - post_id: Post ID

    Required fields:
        - content: Reply content (max 280 chars)
    """
    try:
        data = request.get_json()

        if not data:
            return jsonify({
                'success': False,
                'error': 'Request body required',
                'error_code': 'VALIDATION_EMPTY_BODY'
            }), 400

        content = data.get('content', '').strip()

        # Validate content
        is_valid, error_msg = validate_post_content(content)
        if not is_valid:
            return jsonify({
                'success': False,
                'error': error_msg,
                'error_code': 'VALIDATION_FAILED'
            }), 400

        post = db.session.get(CollxPost, post_id)

        if not post:
            return jsonify({
                'success': False,
                'error': 'Post not found',
                'error_code': 'POST_NOT_FOUND'
            }), 404

        # Create reply
        reply = CollxReply(
            post_id=post_id,
            user_id=user_id,
            content=content
        )

        db.session.add(reply)
        post.reply_count += 1

        # Send notification
        if post.user_id != user_id:
            notify_reply(user_id, post.user_id, post_id, content)

        db.session.commit()

        logger.info(f"Reply created by user {user_id} on post {post_id}")

        return jsonify({
            'success': True,
            'message': 'Reply posted successfully',
            'data': reply.to_dict()
        }), 201

    except Exception as e:
        logger.error(f"Reply post error: {str(e)}", exc_info=True)
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Failed to post reply',
            'error_code': 'REPLY_CREATE_ERROR'
        }), 500


@collx_bp.route('/posts/<int:post_id>/repost', methods=['POST'])
@token_required
def repost_post(user_id, post_id):
    """
    Repost a post (share to your followers)

    Path parameters:
        - post_id: Post ID
    """
    try:
        post = db.session.get(CollxPost, post_id)

        if not post:
            return jsonify({
                'success': False,
                'error': 'Post not found',
                'error_code': 'POST_NOT_FOUND'
            }), 404

        # Increment repost count
        post.repost_count += 1

        # Optionally create a new post referencing the original
        # For now, just increment the count

        db.session.commit()

        logger.info(f"Post {post_id} reposted by user {user_id}")

        return jsonify({
            'success': True,
            'message': 'Post reposted successfully',
            'repost_count': post.repost_count
        })

    except Exception as e:
        logger.error(f"Repost error: {str(e)}", exc_info=True)
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Failed to repost',
            'error_code': 'REPOST_ERROR'
        }), 500


# USER & FOLLOW ENDPOINTS

@collx_bp.route('/users/<int:target_id>', methods=['GET'])
@optional_token
def get_user(user_id, target_id):
    """
    Get user profile with posts
    
    Path parameters:
        - target_id: User ID to fetch
    """
    try:
        user = db.session.get(UserAccount, target_id)
        
        if not user:
            return jsonify({
                'success': False,
                'error': 'User not found',
                'error_code': 'USER_NOT_FOUND'
            }), 404
        
        # Get user's posts
        posts = CollxPost.query.filter_by(
            user_id=target_id
        ).order_by(CollxPost.created_at.desc()).limit(20).all()
        
        # Check if current user follows this user
        is_following = False
        if user_id:
            is_following = CollxFollow.query.filter_by(
                follower_id=user_id,
                following_id=target_id
            ).first() is not None
        
        user_data = user.to_public_dict()
        user_data['is_following'] = is_following
        
        return jsonify({
            'success': True,
            'data': user_data,
            'posts': [p.to_dict() for p in posts]
        })
    
    except Exception as e:
        logger.error(f"Get user error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to fetch user profile',
            'error_code': 'USER_FETCH_ERROR'
        }), 500


@collx_bp.route('/users/<int:target_id>/follow', methods=['POST'])
@token_required
def follow_user(user_id, target_id):
    """
    Toggle follow status for a user
    
    Path parameters:
        - target_id: User ID to follow/unfollow
    """
    try:
        if user_id == target_id:
            return jsonify({
                'success': False,
                'error': "Cannot follow yourself",
                'error_code': 'VALIDATION_CANNOT_FOLLOW_SELF'
            }), 400
        
        target = db.session.get(UserAccount, target_id)
        follower = db.session.get(UserAccount, user_id)
        
        if not target or not follower:
            return jsonify({
                'success': False,
                'error': 'User not found',
                'error_code': 'USER_NOT_FOUND'
            }), 404
        
        # Check existing follow
        existing = CollxFollow.query.filter_by(
            follower_id=user_id,
            following_id=target_id
        ).first()
        
        if existing:
            # Unfollow
            db.session.delete(existing)
            target.follower_count = max(0, target.follower_count - 1)
            follower.following_count = max(0, follower.following_count - 1)
            following = False
        else:
            # Follow
            db.session.add(CollxFollow(
                follower_id=user_id,
                following_id=target_id
            ))
            target.follower_count += 1
            follower.following_count += 1
            following = True
            
            # Send notification
            notify_follow(user_id, target_id)
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'following': following,
            'follower_count': target.follower_count,
            'following_count': follower.following_count
        })
    
    except Exception as e:
        logger.error(f"Follow user error: {str(e)}", exc_info=True)
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Failed to toggle follow',
            'error_code': 'FOLLOW_TOGGLE_ERROR'
        }), 500


# SEARCH & TRENDING

@collx_bp.route('/trending', methods=['GET'])
@optional_token
def trending(user_id):
    """
    Get trending hashtags
    
    Returns top 10 hashtags ranked by engagement score
    """
    try:
        posts = CollxPost.query.all()
        tag_counts = {}
        
        for post in posts:
            if post.hashtags:
                for tag in post.hashtags.split(','):
                    tag = tag.strip()
                    if tag:
                        score = post.like_count * 3 + post.reply_count * 4
                        tag_counts[tag] = tag_counts.get(tag, 0) + score + 1
        
        trending = sorted(
            tag_counts.items(), 
            key=lambda x: x[1], 
            reverse=True
        )[:10]
        
        return jsonify({
            'success': True,
            'data': [
                {'tag': tag, 'score': score} 
                for tag, score in trending
            ]
        })
    
    except Exception as e:
        logger.error(f"Trending hashtags error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to fetch trending hashtags',
            'error_code': 'TRENDING_FETCH_ERROR'
        }), 500


@collx_bp.route('/search', methods=['GET'])
@optional_token
def search(user_id):
    """
    Search users and posts
    
    Query parameters:
        - q: Search query (min 2 characters)
    """
    try:
        query = request.args.get('q', '').strip().lower()
        
        if len(query) < 2:
            return jsonify({
                'success': True,
                'users': [],
                'posts': []
            })
        
        # Search users
        users = UserAccount.query.filter(
            (UserAccount.name.ilike(f'%{query}%')) | 
            (UserAccount.username.ilike(f'%{query}%'))
        ).limit(10).all()
        
        # Search posts
        posts = CollxPost.query.filter(
            CollxPost.content.ilike(f'%{query}%')
        ).order_by(CollxPost.created_at.desc()).limit(20).all()
        
        return jsonify({
            'success': True,
            'users': [u.to_public_dict() for u in users],
            'posts': [p.to_dict() for p in posts],
            'query': query
        })
    
    except Exception as e:
        logger.error(f"Search error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Search failed',
            'error_code': 'SEARCH_ERROR'
        }), 500


# UTILITY ENDPOINTS

@collx_bp.route('/stats', methods=['GET'])
@token_required
def get_stats(user_id):
    """
    Get CollX statistics for current user
    """
    try:
        user = db.session.get(UserAccount, user_id)
        
        if not user:
            return jsonify({
                'success': False,
                'error': 'User not found',
                'error_code': 'USER_NOT_FOUND'
            }), 404
        
        # Get user's stats
        post_count = CollxPost.query.filter_by(user_id=user_id).count()
        total_likes = CollxLike.query.filter_by(user_id=user_id).count()
        total_replies = CollxReply.query.filter_by(user_id=user_id).count()
        
        return jsonify({
            'success': True,
            'stats': {
                'posts': post_count,
                'likes_given': total_likes,
                'replies': total_replies,
                'followers': user.follower_count,
                'following': user.following_count
            }
        })
    
    except Exception as e:
        logger.error(f"Get stats error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to fetch stats',
            'error_code': 'STATS_FETCH_ERROR'
        }), 500
