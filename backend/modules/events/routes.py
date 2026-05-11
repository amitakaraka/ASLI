"""
Events Module Routes — Campus Events & Announcements


"""
from flask import Blueprint, jsonify, request, current_app
from database.models import db, Event, EventRSVP, Announcement, UserAccount
from modules.auth.jwt_utils import token_required, decode_token
from datetime import datetime, timedelta

events_bp = Blueprint('events', __name__, url_prefix='/api')


def _seed_events_if_empty():
    """Add sample events if DB is empty"""
    if Event.query.count() == 0:
        today = datetime.now()
        legacy_events = [
            {
                "title": "Tech Fest 2026",
                "description": "Annual technology festival with coding competitions, hackathons, and tech talks.",
                "date": (today + timedelta(days=15)).strftime("%Y-%m-%d"),
                "time": "9:00 AM",
                "location": "Main Auditorium",
                "image_url": "🎯",
            },
            {
                "title": "Mid-Semester Exams",
                "description": "Mid-semester examinations for all departments.",
                "date": (today + timedelta(days=20)).strftime("%Y-%m-%d"),
                "time": "10:00 AM",
                "location": "Examination Halls",
                "image_url": "📝",
            },
            {
                "title": "Cultural Night",
                "description": "Annual cultural program featuring music, dance, and drama performances.",
                "date": (today + timedelta(days=30)).strftime("%Y-%m-%d"),
                "time": "6:00 PM",
                "location": "Open Air Theatre",
                "image_url": "🎭",
            },
            {
                "title": "Campus Placement Drive",
                "description": "Multiple companies visiting for recruitment. Prepare your resumes!",
                "date": (today + timedelta(days=25)).strftime("%Y-%m-%d"),
                "time": "9:00 AM",
                "location": "Placement Cell",
                "image_url": "💼",
            },
            {
                "title": "Sports Day",
                "description": "Annual sports meet with various athletic events and team competitions.",
                "date": (today + timedelta(days=45)).strftime("%Y-%m-%d"),
                "time": "7:00 AM",
                "location": "Sports Ground",
                "image_url": "🏆",
            },
            {
                "title": "Workshop: AI & Machine Learning",
                "description": "Hands-on workshop on AI/ML fundamentals by industry experts.",
                "date": (today + timedelta(days=10)).strftime("%Y-%m-%d"),
                "time": "2:00 PM",
                "location": "Computer Lab 1",
                "image_url": "🤖",
            },
            {
                "title": "Fee Payment Deadline",
                "description": "Last date to pay semester fees without late fee penalty.",
                "date": (today + timedelta(days=7)).strftime("%Y-%m-%d"),
                "time": "5:00 PM",
                "location": "Accounts Office / Online",
                "image_url": "💰",
            },
            {
                "title": "Alumni Meet",
                "description": "Annual gathering of alumni with networking opportunities.",
                "date": (today + timedelta(days=60)).strftime("%Y-%m-%d"),
                "time": "11:00 AM",
                "location": "Conference Hall",
                "image_url": "🤝",
            },
        ]
        for ev in legacy_events:
            e = Event(title=ev['title'], description=ev['description'], date=ev['date'],
                      time=ev['time'], location=ev['location'], image_url=ev.get('image_url', ''),
                      organizer_id=1)
            db.session.add(e)

        # Seed announcements
        if Announcement.query.count() == 0:
            anncs = [
                {"title": "Library Extended Hours", "content": "Library will remain open until 10 PM during exam week.", "author_id": 1},
                {"title": "New WiFi Password", "content": "Campus WiFi password has been updated. Check your email for details.", "author_id": 1},
                {"title": "Hostel Maintenance", "content": "Water supply will be interrupted on Sunday 8 AM - 12 PM for maintenance.", "author_id": 1},
                {"title": "Semester Registration Open", "content": "Course registration for the upcoming semester is now open. Deadline: April 20th.", "author_id": 1},
                {"title": "Campus Clean-Up Drive", "content": "Volunteers needed for the campus clean-up drive on Saturday morning.", "author_id": 1},
            ]
            for a in anncs:
                db.session.add(Announcement(**a))

        db.session.commit()


@events_bp.route('/events', methods=['GET'])
def get_events():
    """List events"""
    _seed_events_if_empty()
    events = Event.query.filter_by(is_active=True).order_by(Event.date).all()
    # Check for user_id from auth header (optional)
    user_id = None
    auth = request.headers.get('Authorization', '')
    if auth.startswith('Bearer '):
        uid = decode_token(auth.split(' ')[1], current_app.config['JWT_SECRET'])
        if uid:
            user_id = uid

    return jsonify({
        'success': True,
        'count': len(events),
        'data': [e.to_dict(user_id=user_id) for e in events],
    })


@events_bp.route('/events/<int:event_id>/rsvp', methods=['POST'])
@token_required
def rsvp_event(user_id, event_id):
    """Toggle RSVP"""
    event = db.session.get(Event, event_id)
    if not event:
        return jsonify({'error': 'Event not found'}), 404

    existing = EventRSVP.query.filter_by(event_id=event_id, user_id=user_id).first()
    if existing:
        db.session.delete(existing)
        db.session.commit()
        return jsonify({'success': True, 'rsvp': False, 'event': event.to_dict(user_id=user_id)})
    else:
        status = (request.json or {}).get('status', 'going')
        rsvp = EventRSVP(event_id=event_id, user_id=user_id, status=status)
        db.session.add(rsvp)
        db.session.commit()
        return jsonify({'success': True, 'rsvp': True, 'event': event.to_dict(user_id=user_id)})


@events_bp.route('/events/create', methods=['POST'])
@token_required
def create_event(user_id):
    """Create event"""
    data = request.json or {}
    title = data.get('title', '').strip()
    if not title:
        return jsonify({'error': 'Title required'}), 400

    event = Event(
        title=title,
        description=data.get('description', ''),
        date=data.get('date', datetime.now().strftime("%Y-%m-%d")),
        time=data.get('time', ''),
        location=data.get('venue', data.get('location', '')),
        image_url=data.get('image', data.get('image_url', '📅')),
        organizer_id=user_id,
    )
    db.session.add(event)
    db.session.commit()
    return jsonify({'success': True, 'event': event.to_dict(user_id=user_id)}), 201


@events_bp.route('/announcements', methods=['GET'])
def get_announcements():
    """List announcements"""
    _seed_events_if_empty()
    anncs = Announcement.query.order_by(Announcement.created_at.desc()).all()
    return jsonify({
        'success': True,
        'count': len(anncs),
        'data': [a.to_dict() for a in anncs],
    })


@events_bp.route('/announcements/create', methods=['POST'])
@token_required
def create_announcement(user_id):
    """Post announcement"""
    data = request.json or {}
    title = data.get('title', '').strip()
    content = data.get('message', data.get('content', '')).strip()
    if not title or not content:
        return jsonify({'error': 'Title and content required'}), 400

    annc = Announcement(
        title=title,
        content=content,
        author_id=user_id,
    )
    db.session.add(annc)
    db.session.commit()
    return jsonify({'success': True, 'announcement': annc.to_dict()}), 201
