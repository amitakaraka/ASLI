"""
Marketplace Module — Campus Buy/Sell
List items, express interest, mark as sold
"""
from flask import jsonify, request
from . import marketplace_bp
from database.models import db, MarketplaceListing, MarketplaceInterest
from modules.auth.jwt_utils import token_required
from services.notification_service import notify_marketplace_interest


CATEGORIES = ['textbooks', 'notes', 'electronics', 'clothing', 'sports', 'other']
CONDITIONS = ['new', 'like_new', 'good', 'fair', 'poor']


@marketplace_bp.route('/', methods=['GET'])
@token_required
def get_listings(user_id):
    """Get all active listings, optionally by category"""
    category = request.args.get('category', None)
    query = MarketplaceListing.query.filter_by(is_active=True)
    if category and category in CATEGORIES:
        query = query.filter_by(category=category)
    listings = query.order_by(MarketplaceListing.created_at.desc()).all()
    return jsonify({
        'listings': [l.to_dict(user_id=user_id) for l in listings],
        'categories': CATEGORIES,
        'conditions': CONDITIONS,
    })


@marketplace_bp.route('/create', methods=['POST'])
@token_required
def create_listing(user_id):
    """Create a new marketplace listing"""
    data = request.json or {}
    title = data.get('title', '').strip()
    price = data.get('price', 0)

    if not title:
        return jsonify({'error': 'Title is required'}), 400
    try:
        price = float(price)
    except (ValueError, TypeError):
        return jsonify({'error': 'Invalid price'}), 400

    category = data.get('category', 'other')
    if category not in CATEGORIES:
        category = 'other'
    condition = data.get('condition', 'good')
    if condition not in CONDITIONS:
        condition = 'good'

    listing = MarketplaceListing(
        seller_id=user_id,
        title=title,
        description=data.get('description', '').strip(),
        price=price,
        category=category,
        condition=condition,
        image_url=data.get('image_url', ''),
    )
    db.session.add(listing)
    db.session.commit()
    return jsonify({'success': True, 'listing': listing.to_dict(user_id=user_id)})


@marketplace_bp.route('/interest/<int:listing_id>', methods=['POST'])
@token_required
def toggle_interest(user_id, listing_id):
    """Express or remove interest in a listing"""
    listing = db.session.get(MarketplaceListing, listing_id)
    if not listing:
        return jsonify({'error': 'Listing not found'}), 404
    if listing.seller_id == user_id:
        return jsonify({'error': "Can't express interest in your own listing"}), 400

    existing = MarketplaceInterest.query.filter_by(
        listing_id=listing_id, user_id=user_id
    ).first()

    if existing:
        db.session.delete(existing)
        db.session.commit()
        return jsonify({'success': True, 'action': 'removed', 'listing': listing.to_dict(user_id=user_id)})

    data = request.json or {}
    interest = MarketplaceInterest(
        listing_id=listing_id,
        user_id=user_id,
        message=data.get('message', ''),
    )
    db.session.add(interest)
    db.session.commit()
    # Notify seller
    notify_marketplace_interest(user_id, listing.seller_id, listing.title)
    return jsonify({'success': True, 'action': 'added', 'listing': listing.to_dict(user_id=user_id)})


@marketplace_bp.route('/sold/<int:listing_id>', methods=['POST'])
@token_required
def mark_sold(user_id, listing_id):
    """Mark a listing as sold (seller only)"""
    listing = db.session.get(MarketplaceListing, listing_id)
    if not listing:
        return jsonify({'error': 'Listing not found'}), 404
    if listing.seller_id != user_id:
        return jsonify({'error': 'Only the seller can mark as sold'}), 403

    listing.is_sold = not listing.is_sold
    db.session.commit()
    return jsonify({'success': True, 'listing': listing.to_dict(user_id=user_id)})


@marketplace_bp.route('/my', methods=['GET'])
@token_required
def my_listings(user_id):
    """Get listings by the current user"""
    listings = MarketplaceListing.query.filter_by(seller_id=user_id, is_active=True).order_by(MarketplaceListing.created_at.desc()).all()
    return jsonify({'listings': [l.to_dict(user_id=user_id) for l in listings]})
