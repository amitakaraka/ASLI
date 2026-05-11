"""
ASLI Backend - Campus Platform API
Flask backend with modular routes, WebSocket support, and error handling
"""
import os
from datetime import timedelta

from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_socketio import SocketIO
from config import Config
from database.models import (
    db,
    UserAccount,
    CollxPost,
    CollxLike,
    CollxReply,
    CollxFollow,
    Notification,
    DirectMessage,
    Bookmark,
    Poll,
    PollOption,
    PollVote,
    Story,
    StoryView,
    StudyGroup,
    StudyGroupMember,
    GroupMessage,
    CommunityPost,
    Confession,
    ConfessionReaction,
    MarketplaceListing,
    MarketplaceInterest,
    Event,
    EventRSVP,
    Announcement,
    ChatHistory,
    ActivityLog,
)
from modules.auth.routes import auth_bp
from modules.chat.routes import chat_bp
from modules.chat_v2.routes import chat_v2_bp, chatbot_status, init_chatbot
from modules.qa.routes import qa_bp
from modules.collx.routes import collx_bp
from modules.events.routes import events_bp
from modules.notifications.routes import notif_bp
from modules.analytics.routes import analytics_bp
from modules.messages.routes import messages_bp
from modules.admin.routes import admin_bp
from modules.bookmarks.routes import bookmarks_bp
from modules.polls import polls_bp
from modules.stories import stories_bp
from modules.leaderboard import leaderboard_bp
from modules.studygroups import studygroups_bp
from modules.confessions import confessions_bp
from modules.marketplace import marketplace_bp
from modules.community import community_bp
from modules.upload.routes import upload_bp
from modules.socketio_handlers import register_socket_handlers
from utils.observability import error_response, init_observability
from utils.time import utc_now

# Socket.IO for real-time features (chat, notifications). Vercel's Python
# runtime cannot use eventlet, so previews can switch this to "threading".
socketio = SocketIO(async_mode=os.environ.get("ASLI_SOCKETIO_ASYNC_MODE", "eventlet"))


def create_app():
    """Set up and configure the Flask app"""
    Config.validate()

    app = Flask(__name__)
    app.config.from_object(Config)
    app.url_map.strict_slashes = False  # Prevent 301 redirects on missing trailing slash
    init_observability(app)
    
    # CORS setup - allow requests from mobile app and browser
    cors_origins = app.config.get("CORS_ORIGINS", "*")
    CORS(app,
        resources={r"/*": {
            "origins": cors_origins,
            "methods": ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization", "Accept", "X-Requested-With"],
            "expose_headers": ["Content-Length", "X-Total-Count"],
            "max_age": 3600,
        }},
    )

    # DB setup
    db.init_app(app)

    # Register blueprints (modules)
    app.register_blueprint(auth_bp)
    app.register_blueprint(chat_bp)
    app.register_blueprint(qa_bp)
    app.register_blueprint(collx_bp)
    app.register_blueprint(events_bp)
    app.register_blueprint(notif_bp)
    app.register_blueprint(analytics_bp)
    app.register_blueprint(messages_bp)
    app.register_blueprint(admin_bp)
    app.register_blueprint(bookmarks_bp)
    app.register_blueprint(polls_bp)
    app.register_blueprint(stories_bp)
    app.register_blueprint(leaderboard_bp)
    app.register_blueprint(studygroups_bp)
    app.register_blueprint(confessions_bp)
    app.register_blueprint(marketplace_bp)
    app.register_blueprint(community_bp)
    app.register_blueprint(chat_v2_bp)
    app.register_blueprint(upload_bp)

    # Serve uploaded files
    @app.route('/uploads/<path:filename>')
    def serve_upload(filename):
        from flask import send_from_directory
        import os
        upload_folder = os.path.join(os.path.dirname(__file__), 'uploads')
        return send_from_directory(upload_folder, filename)

    # Initialize and register SocketIO handlers
    socketio.init_app(app, cors_allowed_origins=cors_origins)
    register_socket_handlers(socketio)

    # Initialize AI Chatbot
    init_chatbot(app)

    # Health check - simple endpoint for connectivity testing
    @app.route("/", methods=["GET"])
    def home():
        return jsonify(
            {
                "success": True,
                "message": "ASLI Platform Backend",
                "version": "2.1.0",
                "modules": [
                    "auth",
                    "chat",
                    "chat_v2 (AI Chatbot)",
                    "qa",
                    "collx",
                    "events",
                    "notifications",
                    "analytics",
                    "messages",
                    "admin",
                    "bookmarks",
                    "polls",
                    "stories",
                    "leaderboard",
                    "studygroups",
                    "confessions",
                    "marketplace",
                    "community",
                ],
            }
        )

    def _database_health():
        try:
            db.session.execute(db.text("SELECT 1"))
            return {"status": "healthy"}
        except Exception as exc:
            return {"status": "unhealthy", "error": str(exc)}

    # Dedicated liveness check endpoint for mobile clients
    @app.route("/health", methods=["GET"])
    def health():
        return jsonify({
            "status": "ok",
            "timestamp": utc_now().isoformat(),
            "database": _database_health()["status"],
            "version": "2.0.0",
        })

    @app.route("/ready", methods=["GET"])
    def ready():
        checks = {
            "database": _database_health(),
            "chatbot": chatbot_status(),
        }
        is_ready = (
            checks["database"]["status"] == "healthy"
            and checks["chatbot"]["ready"]
        )
        return jsonify({
            "status": "ready" if is_ready else "not_ready",
            "success": is_ready,
            "timestamp": utc_now().isoformat(),
            "checks": checks,
            "version": "2.1.0",
        }), 200 if is_ready else 503

    # ─── Global Error Handlers (return JSON, not HTML) ───
    @app.errorhandler(400)
    def bad_request(e):
        return error_response('Bad request', 400, 'BAD_REQUEST', str(e))

    @app.errorhandler(404)
    def not_found(e):
        return error_response('Not found', 404, 'NOT_FOUND', str(e))

    @app.errorhandler(405)
    def method_not_allowed(e):
        return error_response('Method not allowed', 405, 'METHOD_NOT_ALLOWED', str(e))

    @app.errorhandler(500)
    def internal_error(e):
        db.session.rollback()
        return error_response('Internal server error', 500, 'INTERNAL_SERVER_ERROR')

    @app.errorhandler(Exception)
    def unhandled_exception(e):
        import traceback
        traceback.print_exc()
        db.session.rollback()
        return error_response('Unexpected error', 500, 'UNEXPECTED_ERROR')

    # Schema creation and demo seeding are explicit opt-ins. Production should
    # use migrations instead of mutating the database on import/startup.
    if app.config.get("AUTO_MIGRATE") or app.config.get("SEED_DEMO_DATA"):
        with app.app_context():
            if app.config.get("AUTO_MIGRATE"):
                db.create_all()
            if app.config.get("SEED_DEMO_DATA"):
                seed_data()

    return app


def seed_data():
    """Seed demo users with real accounts"""
    _seed_polls()
    _seed_stories()
    _seed_study_groups()
    _seed_confessions()
    _seed_marketplace()
    _seed_group_messages()
    _seed_community()
    _seed_notifications()
    _seed_dms()
    if UserAccount.query.first():
        return

    users = [
        {
            "name": "Rahul Sharma",
            "username": "rahul_sharma",
            "email": "rahul@au.edu",
            "password": "Test123!",
            "department": "CSE",
            "year": "3rd",
            "bio": "CSE 3rd Year | AI Enthusiast 🤖",
            "profile_color": "#4F46E5",
        },
        {
            "name": "Anita Reddy",
            "username": "anita_r",
            "email": "anita@au.edu",
            "password": "Test123!",
            "department": "ECE",
            "year": "2nd",
            "bio": "ECE 2nd Year | Robotics Club Lead 🔧",
            "profile_color": "#E11D48",
        },
        {
            "name": "Vikram Patel",
            "username": "vikram_p",
            "email": "vikram@au.edu",
            "password": "Test123!",
            "department": "IT",
            "year": "4th",
            "bio": "IT 4th Year | Full-Stack Dev 💻",
            "profile_color": "#059669",
        },
        {
            "name": "Sneha Gupta",
            "username": "sneha_g",
            "email": "sneha@au.edu",
            "password": "Test123!",
            "department": "CSE",
            "year": "2nd",
            "bio": "CSE 2nd Year | ML Researcher 🧠",
            "profile_color": "#D97706",
        },
        {
            "name": "Arjun Nair",
            "username": "arjun_n",
            "email": "arjun@au.edu",
            "password": "Test123!",
            "department": "Mech",
            "year": "3rd",
            "bio": "Mech 3rd Year | Startup Founder 🚀",
            "profile_color": "#7C3AED",
        },
    ]

    for u in users:
        user = UserAccount(
            name=u["name"],
            username=u["username"],
            email=u["email"],
            department=u["department"],
            year=u["year"],
            bio=u["bio"],
            profile_color=u["profile_color"],
        )
        user.set_password(u["password"])
        db.session.add(user)
    db.session.commit()

    # Seed CollX posts
    posts = [
        CollxPost(
            user_id=1,
            content="Hackathon this weekend at AU! Who's in? 🚀 #Hackathon #AU",
            like_count=24,
            reply_count=6,
            hashtags="#Hackathon,#AU",
        ),
        CollxPost(
            user_id=2,
            content="Just finished building an IoT weather station for our ECE project. Super proud of the team! ⚡ #ECE #IoT",
            like_count=18,
            reply_count=3,
            hashtags="#ECE,#IoT",
        ),
        CollxPost(
            user_id=3,
            content="Pro tip: Start your placement prep NOW. Don't wait until final year. Trust me. 💼 #Placements",
            like_count=45,
            reply_count=12,
            hashtags="#Placements",
        ),
        CollxPost(
            user_id=4,
            content="Published my first ML research paper! 🎉 Couldn't have done it without Dr. Sharma's guidance. #ML #Research",
            like_count=67,
            reply_count=8,
            hashtags="#ML,#Research",
        ),
        CollxPost(
            user_id=5,
            content="Our startup just got accepted into AU's incubator program! Let's goooo 🔥 #Startup #Innovation",
            like_count=92,
            reply_count=15,
            hashtags="#Startup,#Innovation",
        ),
        CollxPost(
            user_id=1,
            content="Anyone want to form a team for the upcoming coding contest? Need 2 more members. DM me! #CodingContest",
            like_count=11,
            reply_count=4,
            hashtags="#CodingContest",
        ),
        CollxPost(
            user_id=2,
            content="Library is finally open till 10 PM! Best news this semester 📚 #AU #Library",
            like_count=34,
            reply_count=5,
            hashtags="#AU,#Library",
        ),
        CollxPost(
            user_id=4,
            content="Free AI workshop next Tuesday in Seminar Hall 2. Don't miss it! 🧠 #AIWorkshop #FreeLearning",
            like_count=28,
            reply_count=7,
            hashtags="#AIWorkshop,#FreeLearning",
        ),
    ]
    db.session.add_all(posts)
    db.session.commit()

    # Seed replies
    replies = [
        CollxReply(post_id=1, user_id=2, content="Count me in! 🙋‍♀️"),
        CollxReply(post_id=1, user_id=3, content="Which hall?"),
        CollxReply(
            post_id=3, user_id=4, content="So true! Started in 3rd year myself."
        ),
        CollxReply(post_id=5, user_id=1, content="Congrats Arjun! 🎉"),
    ]
    db.session.add_all(replies)

    # Seed follows
    follows = [
        CollxFollow(follower_id=1, following_id=2),
        CollxFollow(follower_id=1, following_id=4),
        CollxFollow(follower_id=2, following_id=1),
        CollxFollow(follower_id=3, following_id=5),
        CollxFollow(follower_id=4, following_id=1),
        CollxFollow(follower_id=5, following_id=3),
    ]
    db.session.add_all(follows)

    # Update counts
    for u in UserAccount.query.all():
        u.follower_count = CollxFollow.query.filter_by(following_id=u.id).count()
        u.following_count = CollxFollow.query.filter_by(follower_id=u.id).count()

    # Seed DM conversations
    dms = [
        DirectMessage(
            sender_id=2, receiver_id=1, content="Hey Rahul! Ready for the hackathon? 🚀"
        ),
        DirectMessage(
            sender_id=1, receiver_id=2, content="Absolutely! What stack are we using?"
        ),
        DirectMessage(
            sender_id=2,
            receiver_id=1,
            content="I was thinking Flutter + Flask. Thoughts?",
        ),
        DirectMessage(
            sender_id=1, receiver_id=2, content="Perfect combo! Let's do it 💪"
        ),
        DirectMessage(
            sender_id=4, receiver_id=1, content="Rahul, can you review my ML paper?"
        ),
        DirectMessage(
            sender_id=1, receiver_id=4, content="Sure Sneha! Send me the draft"
        ),
        DirectMessage(
            sender_id=4, receiver_id=1, content="Sent to your email. Thanks! 🙏"
        ),
        DirectMessage(
            sender_id=5, receiver_id=3, content="Vikram bhai, placement tips please!"
        ),
        DirectMessage(
            sender_id=3,
            receiver_id=5,
            content="Focus on DSA and system design. DM me anytime!",
        ),
        DirectMessage(
            sender_id=5,
            receiver_id=1,
            content="Hey Rahul! Want to join our startup team?",
        ),
        DirectMessage(
            sender_id=1,
            receiver_id=5,
            content="Sounds interesting! Tell me more about it",
        ),
    ]
    db.session.add_all(dms)

    db.session.commit()
    print("✅ Seed data loaded — 5 users, 8 posts, 4 replies, 6 follows, 11 DMs")


def _seed_polls():
    """Seed polls independently"""
    if Poll.query.count() == 0:
        poll1 = Poll(
            question="What's the best programming language for beginners?", creator_id=2
        )
        db.session.add(poll1)
        db.session.flush()
        for opt in ["Python", "JavaScript", "Java", "C++"]:
            db.session.add(PollOption(poll_id=poll1.id, text=opt))

        poll2 = Poll(question="Best campus food spot?", creator_id=3)
        db.session.add(poll2)
        db.session.flush()
        for opt in ["Canteen", "Street Food", "Mess Hall"]:
            db.session.add(PollOption(poll_id=poll2.id, text=opt))

        poll3 = Poll(question="Preferred study time?", creator_id=4)
        db.session.add(poll3)
        db.session.flush()
        for opt in ["Morning 🌅", "Afternoon ☀️", "Night 🌙", "All-nighter 💀"]:
            db.session.add(PollOption(poll_id=poll3.id, text=opt))

        db.session.commit()
        print("🗳️  Seeded 3 polls")


def _seed_stories():
    """Seed stories independently"""
    if Story.query.count() == 0:
        stories = [
            Story(
                creator_id=2,
                text="Just aced my Data Structures exam! 💪 The grind pays off.",
                bg_color="#E11D48",
                emoji="🎉",
                expires_at=utc_now() + timedelta(hours=20),
            ),
            Story(
                creator_id=3,
                text="Beautiful sunset from the campus rooftop today 🌅",
                bg_color="#F59E0B",
                emoji="🌅",
                expires_at=utc_now() + timedelta(hours=18),
            ),
            Story(
                creator_id=4,
                text="New ML research paper published! Check it out on our lab page.",
                bg_color="#8B5CF6",
                emoji="🧠",
                expires_at=utc_now() + timedelta(hours=22),
            ),
            Story(
                creator_id=5,
                text="Hackathon this weekend! Team Innovators is recruiting 🚀",
                bg_color="#10B981",
                emoji="🚀",
                expires_at=utc_now() + timedelta(hours=15),
            ),
            Story(
                creator_id=2,
                text="Late night coding session with the squad 💻",
                bg_color="#3B82F6",
                emoji="💻",
                expires_at=utc_now() + timedelta(hours=12),
            ),
        ]
        db.session.add_all(stories)
        db.session.commit()
        print("📸  Seeded 5 stories")


def _seed_study_groups():
    """Seed study groups independently"""
    if StudyGroup.query.count() == 0:
        groups_data = [
            {
                "name": "DSA Warriors",
                "subject": "Data Structures & Algorithms",
                "description": "Prep for placements! We solve 3 problems daily and discuss approaches.",
                "emoji": "💻",
                "color": "#3B82F6",
                "creator_id": 1,
                "members": [1, 2, 4],
            },
            {
                "name": "ML Research Lab",
                "subject": "Machine Learning",
                "description": "Reading papers, implementing models, and discussing the latest in AI/ML.",
                "emoji": "🧠",
                "color": "#8B5CF6",
                "creator_id": 4,
                "members": [4, 1, 3, 5],
            },
            {
                "name": "Web Dev Crew",
                "subject": "Full Stack Development",
                "description": "React, Node.js, databases — building real projects together!",
                "emoji": "🌐",
                "color": "#10B981",
                "creator_id": 2,
                "members": [2, 3],
            },
        ]
        for gd in groups_data:
            group = StudyGroup(
                name=gd["name"],
                subject=gd["subject"],
                description=gd["description"],
                emoji=gd["emoji"],
                color=gd["color"],
                creator_id=gd["creator_id"],
            )
            db.session.add(group)
            db.session.flush()
            for uid in gd["members"]:
                role = "admin" if uid == gd["creator_id"] else "member"
                db.session.add(
                    StudyGroupMember(group_id=group.id, user_id=uid, role=role)
                )
        db.session.commit()
        print("📚  Seeded 3 study groups")


def _seed_confessions():
    """Seed anonymous confessions"""
    if Confession.query.count() == 0:
        confessions_data = [
            {
                "content": "I have a massive crush on someone in my DSA class but I'm too scared to talk to them. They always sit in the third row and explain doubts so well 🥺",
                "category": "crush",
                "mood": "😍",
                "author_id": 2,
            },
            {
                "content": "I've been copying assignments for 3 semesters and nobody has ever noticed. The guilt is eating me alive but I genuinely don't understand the subject.",
                "category": "academics",
                "mood": "😔",
                "author_id": 3,
            },
            {
                "content": "The mess food today was actually good?? Am I dreaming or did they actually hire a new cook? That paneer was chef's kiss 👨‍🍳",
                "category": "hostel",
                "mood": "😋",
                "author_id": 5,
            },
            {
                "content": "WHY does the WiFi in the library go down EXACTLY during exam season?? It's like they WANT us to fail. Every. Single. Time. 💢",
                "category": "rant",
                "mood": "😤",
                "author_id": 1,
            },
            {
                "content": 'Our professor walked into the wrong classroom today, taught for 10 minutes, then realized and just said "well, free knowledge" and left 😂',
                "category": "funny",
                "mood": "😂",
                "author_id": 4,
            },
            {
                "content": "I pretend to study in the library but I'm actually watching Netflix with one earbud in. Been doing this for a month. No regrets.",
                "category": "general",
                "mood": "😎",
                "author_id": 2,
            },
        ]
        for cd in confessions_data:
            c = Confession(**cd)
            db.session.add(c)
        db.session.flush()
        # Add some reactions
        reactions = [
            (1, 2, "😂"),
            (1, 3, "❤️"),
            (2, 1, "😢"),
            (3, 4, "🔥"),
            (4, 2, "🔥"),
            (4, 5, "😂"),
            (5, 1, "😂"),
            (5, 3, "😂"),
            (5, 5, "😂"),
            (6, 4, "💀"),
            (6, 1, "😂"),
        ]
        for conf_id, uid, emoji in reactions:
            db.session.add(
                ConfessionReaction(confession_id=conf_id, user_id=uid, emoji=emoji)
            )
        db.session.commit()
        print("🎭  Seeded 6 confessions with reactions")


def _seed_marketplace():
    """Seed marketplace listings"""
    if MarketplaceListing.query.count() == 0:
        listings_data = [
            {'seller_id': 1, 'title': 'Data Structures Textbook (Cormen)', 'description': 'CLRS 3rd Edition. Slight highlighting in first 3 chapters. Perfect for DSA prep.', 'price': 350, 'category': 'textbooks', 'condition': 'good'},
            {'seller_id': 2, 'title': 'MacBook Air M1 Charger', 'description': 'Original Apple 30W charger. Works perfectly, upgraded to MagSafe.', 'price': 1200, 'category': 'electronics', 'condition': 'like_new'},
            {'seller_id': 3, 'title': 'Complete DBMS Notes (Handwritten)', 'description': '80 pages of comprehensive DBMS notes covering SQL, normalization, ER diagrams. Got 9.5 SGPA with these!', 'price': 100, 'category': 'notes', 'condition': 'good'},
            {'seller_id': 4, 'title': 'College Hoodie - XL', 'description': 'Official AU branded hoodie. Navy blue, XL size. Worn twice, too big for me.', 'price': 600, 'category': 'clothing', 'condition': 'like_new'},
            {'seller_id': 5, 'title': 'Badminton Racket - Yonex', 'description': 'Yonex Nanoray, used for one semester. Comes with cover and 3 shuttlecocks.', 'price': 800, 'category': 'sports', 'condition': 'good'},
            {'seller_id': 1, 'title': 'Scientific Calculator - Casio fx-991EX', 'description': 'Classwiz model. Perfect for engineering exams. All functions working.', 'price': 500, 'category': 'electronics', 'condition': 'good'},
        ]
        for ld in listings_data:
            db.session.add(MarketplaceListing(**ld))
        db.session.flush()
        # Add some interests
        interests = [
            (1, 3, "Is the price negotiable?"), (1, 4, ""),
            (2, 1, "Can you do 1000?"), (3, 2, "Need this!"),
            (4, 5, ""), (5, 1, "Still available?"),
        ]
        for lid, uid, msg in interests:
            db.session.add(MarketplaceInterest(listing_id=lid, user_id=uid, message=msg))
        db.session.commit()
        print("🛒  Seeded 6 marketplace listings with interests")


def _seed_group_messages():
    """Seed group chat messages for study groups"""
    if GroupMessage.query.count() == 0 and StudyGroup.query.count() > 0:
        groups = StudyGroup.query.all()
        messages_data = {
            1: [  # DSA Warriors
                (1, "Hey everyone! Let's start with arrays today 💪"),
                (2, "Sure! I just solved the Two Sum problem on LeetCode"),
                (4, "Can someone explain the sliding window technique?"),
                (1, "@Sneha it's basically keeping a window of elements and moving it across. I'll share my notes."),
                (2, "Here's a great YouTube link: NeetCode's playlist is 🔥"),
                (4, "Thanks! Also, when are we doing the mock interview session?"),
                (1, "This Saturday 3 PM. I'll send a reminder."),
            ],
            2: [  # ML Research Lab
                (4, "Just finished reading the Attention Is All You Need paper 🧠"),
                (1, "That's a classic! The transformer architecture changed everything"),
                (3, "I'm implementing a BERT model for our project"),
                (5, "Anyone tried fine-tuning GPT for code generation?"),
                (4, "Yes! Check out the CodeParrot paper. Really good."),
                (1, "Let's discuss the loss function convergence issue I'm facing"),
            ],
            3: [  # Web Dev Crew
                (2, "React 19 is out! Who's upgrading? 🌐"),
                (3, "Already did. The server components are game-changing"),
                (2, "I'm building a Next.js portfolio. Anyone want to collab?"),
                (3, "Count me in! I'll handle the backend with FastAPI"),
            ],
        }
        for gid, msgs in messages_data.items():
            if gid <= len(groups):
                for sender_id, content in msgs:
                    m = GroupMessage(
                        group_id=gid,
                        sender_id=sender_id,
                        content=content,
                        message_type='text',
                    )
                    db.session.add(m)
        db.session.commit()
        print("💬  Seeded group chat messages")


def _seed_community():
    """Seed community channel posts"""
    if CommunityPost.query.count() == 0:
        posts_data = [
            ('general',   1, 'Welcome to ASLI Community! 🎉 This is the official campus channel. Share updates, ask questions, help each other.'),
            ('general',   2, 'Does anyone know when the new semester timetable is coming out? 📅'),
            ('general',   3, 'Library extended hours confirmed till 10 PM during exam week! 📚'),
            ('general',   5, 'Lost my calculator in the exam hall yesterday. If found, please DM me 🙏'),
            ('academic',  4, 'Sharing my handwritten DBMS notes — 80 pages covering normalization, SQL, and ER diagrams. DM if needed!'),
            ('academic',  1, 'Important: Data Structures assignment deadline extended to Friday'),
            ('academic',  2, 'Free AI/ML workshop next Tuesday in Seminar Hall 2. Register on the events page!'),
            ('placement', 3, 'TCS NQT registrations are open! Last date: April 15th. Apply now.'),
            ('placement', 1, 'Pro tip: Practice at least 3 DSA problems daily. Start with Easy, then move to Medium.'),
            ('placement', 5, 'Infosys Power Programmer test pattern changed this year. Has anyone given it?'),
            ('events',    2, 'Tech Fest 2026 registrations are OPEN! 🚀 Hackathon, coding contest, robo wars all in one weekend!'),
            ('events',    4, 'Cultural Night is on April 30th. Dance team auditions tomorrow 4 PM at Open Air Theatre.'),
            ('sports',    5, 'Cricket tournament starting next week. Team registrations at sports office.'),
            ('sports',    1, 'New gym timings: 6-9 AM and 4-7 PM. ID card mandatory.'),
        ]
        for channel, author_id, content in posts_data:
            p = CommunityPost(channel=channel, author_id=author_id, content=content)
            db.session.add(p)
        db.session.commit()
        print("🏘️  Seeded 14 community posts across 5 channels")


def _seed_notifications():
    """Seed realistic notifications for demo"""
    if Notification.query.first():
        return
    now = utc_now()
    notifs = [
        Notification(user_id=1, type='like', title='Arjun Nair liked your post', body='Tap to view', actor_id=2, post_id=1, created_at=now - timedelta(minutes=15)),
        Notification(user_id=1, type='follow', title='Sneha Gupta started following you', body='@sneha_g', actor_id=3, created_at=now - timedelta(minutes=30)),
        Notification(user_id=1, type='reply', title='Anita Reddy replied to your post', body='Great insight on AI trends!', actor_id=4, post_id=2, created_at=now - timedelta(hours=1)),
        Notification(user_id=1, type='like', title='Sneha Gupta liked your post', body='Tap to view', actor_id=3, post_id=3, created_at=now - timedelta(hours=2)),
        Notification(user_id=1, type='system', title='Welcome to ASLI! 🎉', body='Explore your campus companion for AU Centenary Year', created_at=now - timedelta(hours=5)),
        Notification(user_id=2, type='follow', title='Rahul Sharma started following you', body='@rahul_s', actor_id=1, created_at=now - timedelta(minutes=20)),
        Notification(user_id=2, type='like', title='Anita Reddy liked your post', body='Tap to view', actor_id=4, post_id=4, created_at=now - timedelta(hours=1)),
        Notification(user_id=3, type='like', title='Rahul Sharma liked your post', body='Tap to view', actor_id=1, post_id=5, created_at=now - timedelta(minutes=45)),
        Notification(user_id=3, type='system', title='New Poll: Favourite canteen food?', body='Cast your vote now!', created_at=now - timedelta(hours=3)),
        Notification(user_id=4, type='follow', title='Arjun Nair started following you', body='@arjun_n', actor_id=2, created_at=now - timedelta(hours=1)),
    ]
    db.session.add_all(notifs)
    db.session.commit()
    print("🔔 Seeded 10 notifications")


def _seed_dms():
    """Seed direct message conversations for demo"""
    if DirectMessage.query.first():
        return
    now = utc_now()
    dms = [
        # Rahul <-> Arjun conversation
        DirectMessage(sender_id=2, receiver_id=1, content='Hey Rahul! Did you submit the ML assignment?', created_at=now - timedelta(hours=5)),
        DirectMessage(sender_id=1, receiver_id=2, content='Not yet, working on it. The CNN part is tricky 😅', created_at=now - timedelta(hours=4, minutes=50)),
        DirectMessage(sender_id=2, receiver_id=1, content='Same! Let me know if you want to discuss it', created_at=now - timedelta(hours=4, minutes=45)),
        DirectMessage(sender_id=1, receiver_id=2, content='Sure, lets meet at the library at 4?', created_at=now - timedelta(hours=4, minutes=40)),
        DirectMessage(sender_id=2, receiver_id=1, content='Perfect! See you there 👍', created_at=now - timedelta(hours=4, minutes=35)),
        # Rahul <-> Sneha conversation
        DirectMessage(sender_id=3, receiver_id=1, content='Hi Rahul! Are you going to the Tech Fest?', created_at=now - timedelta(hours=3)),
        DirectMessage(sender_id=1, receiver_id=3, content='Yes! I registered for the hackathon and coding contest 🚀', created_at=now - timedelta(hours=2, minutes=50)),
        DirectMessage(sender_id=3, receiver_id=1, content='Awesome! I signed up for hackathon too. We should team up!', created_at=now - timedelta(hours=2, minutes=40)),
        DirectMessage(sender_id=1, receiver_id=3, content='Great idea! Lets form a team. I know Arjun is also looking.', created_at=now - timedelta(hours=2, minutes=30)),
        # Arjun <-> Sneha conversation  
        DirectMessage(sender_id=2, receiver_id=3, content='Sneha, can you share the placement prep resources?', created_at=now - timedelta(hours=6)),
        DirectMessage(sender_id=3, receiver_id=2, content='Sure! I have a Google Drive link. Will share in the study group.', created_at=now - timedelta(hours=5, minutes=45)),
    ]
    db.session.add_all(dms)
    db.session.commit()
    print("💬 Seeded 11 DM conversations")


# RUN

app = create_app()

if __name__ == "__main__":
    print("\n🎓 ASLI Platform Backend v20.0")
    print("🏗️  18 Modules | Real-time WebSocket | JWT Auth | Global Error Handling")
    print("=" * 55)
    print(
        "Modules: auth | chat | chat-v2 | qa | collx | events | notifs | analytics | messages | admin | bookmarks | polls | stories | leaderboard | studygroups | confessions | marketplace | community"
    )
    print("Server:  http://127.0.0.1:5001")
    print("WebSocket: ws://127.0.0.1:5001/socket.io")
    print("=" * 55)
    socketio.run(app, debug=True, host="0.0.0.0", port=5001, use_reloader=False)
