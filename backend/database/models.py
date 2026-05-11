"""
ASLI Database Models
SQLAlchemy models for all platform features
"""
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, timedelta
from werkzeug.security import generate_password_hash, check_password_hash
import re
from utils.time import utc_now

db = SQLAlchemy()


# Mixins

class TimestampMixin:
    """Auto-set created/updated timestamps"""
    created_at = db.Column(db.DateTime, default=utc_now, nullable=False, index=True)
    updated_at = db.Column(db.DateTime, default=utc_now, onupdate=utc_now, nullable=False, index=True)


class SoftDeleteMixin:
    """Soft delete support"""
    is_deleted = db.Column(db.Boolean, default=False, nullable=False, index=True)
    deleted_at = db.Column(db.DateTime, nullable=True)


# --- User ---

class UserAccount(db.Model, TimestampMixin):
    """
    User account model with authentication and profile management
    Table: user_account
    """
    __tablename__ = 'user_account'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(100), nullable=False, index=True)
    email = db.Column(db.String(150), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(256), nullable=False)
    username = db.Column(db.String(50), unique=True, nullable=False, index=True)
    
    # Profile fields
    department = db.Column(db.String(100), default="", nullable=False)
    year = db.Column(db.String(20), default="", nullable=False)
    bio = db.Column(db.String(160), default="", nullable=False)
    profile_color = db.Column(db.String(10), default="#A9523C", nullable=False)
    avatar_url = db.Column(db.String(300), default="", nullable=True)
    
    # Stats
    follower_count = db.Column(db.Integer, default=0, nullable=False)
    following_count = db.Column(db.Integer, default=0, nullable=False)
    post_count = db.Column(db.Integer, default=0, nullable=False)
    
    # Account status
    is_active = db.Column(db.Boolean, default=True, nullable=False, index=True)
    is_verified = db.Column(db.Boolean, default=False, nullable=False)
    is_admin = db.Column(db.Boolean, default=False, nullable=False)
    
    # Relationships
    posts = db.relationship('CollxPost', backref='author', lazy='dynamic', cascade='all, delete-orphan')
    replies = db.relationship('CollxReply', backref='author', lazy='dynamic', cascade='all, delete-orphan')
    notifications = db.relationship('Notification', foreign_keys='Notification.user_id', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    sent_dms = db.relationship('DirectMessage', backref='sender', lazy='dynamic', 
                               foreign_keys='DirectMessage.sender_id', cascade='all, delete-orphan')
    received_dms = db.relationship('DirectMessage', backref='receiver', lazy='dynamic',
                                   foreign_keys='DirectMessage.receiver_id')
    bookmarks = db.relationship('Bookmark', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    
    
    __table_args__ = (
        db.Index('idx_user_email', 'email'),
        db.Index('idx_user_username', 'username'),
        db.Index('idx_user_name', 'name'),
        db.Index('idx_user_active', 'is_active'),
    )

    def set_password(self, password):
        """Hash and set password"""
        self.password_hash = generate_password_hash(password, method='pbkdf2:sha256')

    def check_password(self, password):
        """Verify password"""
        return check_password_hash(self.password_hash, password)

    @staticmethod
    def validate_email(email):
        """Validate email format"""
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return re.match(pattern, email) is not None

    @staticmethod
    def validate_username(username):
        """Validate username format"""
        pattern = r'^[a-zA-Z0-9_]{3,20}$'
        return re.match(pattern, username) is not None

    def to_dict(self, include_email=False):
        """Convert to dictionary (includes sensitive fields for owner)"""
        data = {
            "id": self.id,
            "name": self.name,
            "username": self.username,
            "department": self.department,
            "year": self.year,
            "bio": self.bio,
            "profile_color": self.profile_color,
            "avatar_url": self.avatar_url,
            "follower_count": self.follower_count,
            "following_count": self.following_count,
            "post_count": self.post_count,
            "is_verified": self.is_verified,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
        if include_email:
            data["email"] = self.email
        return data

    def to_public_dict(self):
        """Public profile without sensitive fields"""
        return self.to_dict(include_email=False)

    def __repr__(self):
        return f'<UserAccount {self.username}>'


# Q&A MODULE

class Question(db.Model, TimestampMixin):
    """Question in Q&A system"""
    __tablename__ = 'question'
    
    id = db.Column(db.Integer, primary_key=True)
    text = db.Column(db.String(500), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=True, index=True)
    is_answered = db.Column(db.Boolean, default=False, index=True)
    answer_count = db.Column(db.Integer, default=0)
    
    answers = db.relationship('Answer', backref='question', lazy='dynamic', cascade='all, delete-orphan')
    
    def to_dict(self):
        return {
            "id": self.id,
            "text": self.text,
            "user_id": self.user_id,
            "is_answered": self.is_answered,
            "answer_count": self.answer_count,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class Answer(db.Model, TimestampMixin):
    """Answer to a question"""
    __tablename__ = 'answer'
    
    id = db.Column(db.Integer, primary_key=True)
    question_id = db.Column(db.Integer, db.ForeignKey('question.id'), nullable=False, index=True)
    text = db.Column(db.String(500), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=True, index=True)
    is_accepted = db.Column(db.Boolean, default=False)
    upvote_count = db.Column(db.Integer, default=0)
    
    def to_dict(self):
        return {
            "id": self.id,
            "question_id": self.question_id,
            "text": self.text,
            "user_id": self.user_id,
            "is_accepted": self.is_accepted,
            "upvote_count": self.upvote_count,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


# COLLX SOCIAL MODULE

class CollxPost(db.Model, TimestampMixin):
    """
    CollX social media post (microblog)
    Table: collx_post
    """
    __tablename__ = 'collx_post'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    content = db.Column(db.String(280), nullable=False)
    image_url = db.Column(db.String(500), default="", nullable=True)
    
    # Engagement metrics
    like_count = db.Column(db.Integer, default=0, nullable=False)
    reply_count = db.Column(db.Integer, default=0, nullable=False)
    repost_count = db.Column(db.Integer, default=0, nullable=False)
    bookmark_count = db.Column(db.Integer, default=0, nullable=False)
    
    # Metadata
    hashtags = db.Column(db.String(500), default="", nullable=True)
    is_pinned = db.Column(db.Boolean, default=False)
    
    # Relationships
    replies = db.relationship('CollxReply', backref='post', lazy='dynamic', cascade='all, delete-orphan')
    likes = db.relationship('CollxLike', backref='post', lazy='dynamic', cascade='all, delete-orphan')
    bookmarks = db.relationship('Bookmark', backref='post', lazy='dynamic', cascade='all, delete-orphan')
    
    
    __table_args__ = (
        db.Index('idx_post_created_at', 'created_at'),
        db.Index('idx_post_user_created', 'user_id', 'created_at'),
        db.Index('idx_post_hashtags', 'hashtags'),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "author_name": self.author.name if self.author else "Unknown",
            "author_username": self.author.username if self.author else "unknown",
            "author_color": self.author.profile_color if self.author else "#A9523C",
            "author_avatar": self.author.avatar_url if self.author and self.author.avatar_url else None,
            "content": self.content,
            "image_url": self.image_url,
            "like_count": self.like_count,
            "reply_count": self.reply_count,
            "repost_count": self.repost_count,
            "bookmark_count": self.bookmark_count,
            "hashtags": self.hashtags,
            "is_pinned": self.is_pinned,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class CollxLike(db.Model):
    """Like on a CollX post"""
    __tablename__ = 'collx_like'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    post_id = db.Column(db.Integer, db.ForeignKey('collx_post.id'), nullable=False, index=True)
    created_at = db.Column(db.DateTime, default=utc_now, nullable=False)
    
    # Unique constraint - one like per user per post
    __table_args__ = (
        db.UniqueConstraint('user_id', 'post_id', name='unique_user_post_like'),
        db.Index('idx_like_user', 'user_id'),
        db.Index('idx_like_post', 'post_id'),
    )


class CollxReply(db.Model, TimestampMixin):
    """Reply to a CollX post"""
    __tablename__ = 'collx_reply'
    
    id = db.Column(db.Integer, primary_key=True)
    post_id = db.Column(db.Integer, db.ForeignKey('collx_post.id'), nullable=False, index=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    content = db.Column(db.String(280), nullable=False)
    like_count = db.Column(db.Integer, default=0, nullable=False)
    parent_id = db.Column(db.Integer, db.ForeignKey('collx_reply.id'), nullable=True)
    
    # Self-referential relationship for nested replies
    replies = db.relationship('CollxReply', backref=db.backref('parent', remote_side=[id]))
    
    
    __table_args__ = (
        db.Index('idx_reply_post_created', 'post_id', 'created_at'),
        db.Index('idx_reply_user', 'user_id'),
    )

    def to_dict(self):
        author = db.session.get(UserAccount, self.user_id)
        return {
            "id": self.id,
            "post_id": self.post_id,
            "user_id": self.user_id,
            "author_name": author.name if author else "Unknown",
            "author_username": author.username if author else "unknown",
            "author_color": author.profile_color if author else "#A9523C",
            "content": self.content,
            "like_count": self.like_count,
            "parent_id": self.parent_id,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class CollxFollow(db.Model, TimestampMixin):
    """User follow"""
    __tablename__ = 'collx_follow'
    
    id = db.Column(db.Integer, primary_key=True)
    follower_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    following_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    
    # Relationships
    follower = db.relationship('UserAccount', foreign_keys=[follower_id], backref='following')
    following = db.relationship('UserAccount', foreign_keys=[following_id], backref='followers')
    
    # Unique constraint
    __table_args__ = (
        db.UniqueConstraint('follower_id', 'following_id', name='unique_follow_pair'),
    )


# NOTIFICATION MODULE

class Notification(db.Model, TimestampMixin):
    """Notification"""
    __tablename__ = 'notification'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    type = db.Column(db.String(30), nullable=False, index=True)  # like, reply, follow, mention, system
    title = db.Column(db.String(200), nullable=False)
    body = db.Column(db.String(500), default="")
    
    # References
    actor_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=True, index=True)
    post_id = db.Column(db.Integer, nullable=True, index=True)
    reply_id = db.Column(db.Integer, nullable=True)
    
    # Status
    is_read = db.Column(db.Boolean, default=False, index=True)
    read_at = db.Column(db.DateTime, nullable=True)
    
    
    __table_args__ = (
        db.Index('idx_notification_user_read', 'user_id', 'is_read'),
        db.Index('idx_notification_created', 'created_at'),
    )

    def to_dict(self):
        actor = db.session.get(UserAccount, self.actor_id) if self.actor_id else None
        return {
            "id": self.id,
            "user_id": self.user_id,
            "type": self.type,
            "title": self.title,
            "body": self.body,
            "actor_id": self.actor_id,
            "actor_name": actor.name if actor else None,
            "actor_username": actor.username if actor else None,
            "actor_color": actor.profile_color if actor else None,
            "post_id": self.post_id,
            "is_read": self.is_read,
            "read_at": self.read_at.isoformat() if self.read_at else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


# MESSAGING MODULE

class DirectMessage(db.Model, TimestampMixin):
    """Private direct message between users"""
    __tablename__ = 'direct_message'
    
    id = db.Column(db.Integer, primary_key=True)
    sender_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    receiver_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    content = db.Column(db.String(1000), nullable=False)
    message_type = db.Column(db.String(20), default="text")  # text, image, video, file
    media_url = db.Column(db.String(500), nullable=True)
    
    # Status
    is_read = db.Column(db.Boolean, default=False, index=True)
    is_deleted = db.Column(db.Boolean, default=False)
    read_at = db.Column(db.DateTime, nullable=True)
    
    
    __table_args__ = (
        db.Index('idx_dm_sender_receiver', 'sender_id', 'receiver_id'),
        db.Index('idx_dm_created', 'created_at'),
    )

    def to_dict(self):
        sender = db.session.get(UserAccount, self.sender_id)
        receiver = db.session.get(UserAccount, self.receiver_id)
        return {
            "id": self.id,
            "sender_id": self.sender_id,
            "receiver_id": self.receiver_id,
            "sender_name": sender.name if sender else "Unknown",
            "sender_username": sender.username if sender else "unknown",
            "sender_color": sender.profile_color if sender else "#A9523C",
            "receiver_name": receiver.name if receiver else "Unknown",
            "content": self.content,
            "message_type": self.message_type,
            "media_url": self.media_url,
            "is_read": self.is_read,
            "read_at": self.read_at.isoformat() if self.read_at else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class Conversation(db.Model, TimestampMixin):
    """Conversation metadata for DM grouping"""
    __tablename__ = 'conversation'
    
    id = db.Column(db.Integer, primary_key=True)
    participant_ids = db.Column(db.String(50), nullable=False, index=True)  # "1_2" format
    last_message_id = db.Column(db.Integer, nullable=True)
    last_message_at = db.Column(db.DateTime, nullable=True, index=True)
    unread_count = db.Column(db.Integer, default=0)
    
    __table_args__ = (
        db.Index('idx_conversation_participants', 'participant_ids'),
    )


# BOOKMARK MODULE

class Bookmark(db.Model, TimestampMixin):
    """Saved/bookmarked posts"""
    __tablename__ = 'bookmark'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    post_id = db.Column(db.Integer, db.ForeignKey('collx_post.id'), nullable=False, index=True)
    
    # Unique constraint
    __table_args__ = (
        db.UniqueConstraint('user_id', 'post_id', name='unique_bookmark'),
        db.Index('idx_bookmark_user', 'user_id'),
        db.Index('idx_bookmark_post', 'post_id'),
    )

    def to_dict(self):
        post = db.session.get(CollxPost, self.post_id)
        return {
            "id": self.id,
            "user_id": self.user_id,
            "post_id": self.post_id,
            "post": post.to_dict() if post else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


# POLL MODULE

class Poll(db.Model, TimestampMixin):
    """Interactive poll for CollX feed"""
    __tablename__ = 'poll'
    
    id = db.Column(db.Integer, primary_key=True)
    question = db.Column(db.String(280), nullable=False)
    creator_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    expires_at = db.Column(db.DateTime, nullable=True, index=True)
    is_active = db.Column(db.Boolean, default=True, index=True)
    total_votes = db.Column(db.Integer, default=0)
    
    options = db.relationship('PollOption', backref='poll', lazy='dynamic', cascade='all, delete-orphan')
    votes = db.relationship('PollVote', backref='poll', lazy='dynamic', cascade='all, delete-orphan')
    
    
    __table_args__ = (
        db.Index('idx_poll_creator', 'creator_id'),
        db.Index('idx_poll_expires', 'expires_at'),
    )

    def to_dict(self, user_id=None):
        total_votes = self.votes.count()
        user_vote = None
        if user_id:
            vote = PollVote.query.filter_by(poll_id=self.id, user_id=user_id).first()
            user_vote = vote.option_id if vote else None

        creator = db.session.get(UserAccount, self.creator_id)
        options_data = []
        for opt in self.options:
            vote_count = PollVote.query.filter_by(option_id=opt.id).count()
            pct = round((vote_count / total_votes * 100), 1) if total_votes > 0 else 0
            options_data.append({
                "id": opt.id,
                "text": opt.text,
                "votes": vote_count,
                "percentage": pct,
            })

        return {
            "id": self.id,
            "question": self.question,
            "creator_id": self.creator_id,
            "creator_name": creator.name if creator else "Unknown",
            "creator_username": creator.username if creator else "user",
            "creator_color": creator.profile_color if creator else "#A9523C",
            "options": options_data,
            "total_votes": total_votes,
            "user_vote": user_vote,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
            "is_active": self.is_active,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class PollOption(db.Model):
    """Poll option"""
    __tablename__ = 'poll_option'
    
    id = db.Column(db.Integer, primary_key=True)
    poll_id = db.Column(db.Integer, db.ForeignKey('poll.id'), nullable=False, index=True)
    text = db.Column(db.String(120), nullable=False)
    order = db.Column(db.Integer, default=0)


class PollVote(db.Model, TimestampMixin):
    """User vote on a poll"""
    __tablename__ = 'poll_vote'
    
    id = db.Column(db.Integer, primary_key=True)
    poll_id = db.Column(db.Integer, db.ForeignKey('poll.id'), nullable=False, index=True)
    option_id = db.Column(db.Integer, db.ForeignKey('poll_option.id'), nullable=False, index=True)
    user_id = db.Column(db.Integer, nullable=False, index=True)
    
    # Unique constraint - one vote per user per poll
    __table_args__ = (
        db.UniqueConstraint('poll_id', 'user_id', name='unique_poll_vote'),
        db.Index('idx_vote_poll', 'poll_id'),
        db.Index('idx_vote_option', 'option_id'),
    )


# STORY MODULE

class Story(db.Model):
    """Ephemeral story - 24h auto-expiry"""
    __tablename__ = 'story'
    
    id = db.Column(db.Integer, primary_key=True)
    creator_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    text = db.Column(db.String(500), nullable=False)
    bg_color = db.Column(db.String(20), default='#A9523C')
    emoji = db.Column(db.String(10), nullable=True)
    image_url = db.Column(db.String(500), nullable=True)
    created_at = db.Column(db.DateTime, default=utc_now, nullable=False, index=True)
    expires_at = db.Column(db.DateTime, nullable=False, index=True)
    view_count = db.Column(db.Integer, default=0)
    
    views = db.relationship('StoryView', backref='story', lazy='dynamic', cascade='all, delete-orphan')
    
    
    __table_args__ = (
        db.Index('idx_story_creator_expires', 'creator_id', 'expires_at'),
        db.Index('idx_story_expires', 'expires_at'),
    )

    def to_dict(self, user_id=None):
        creator = db.session.get(UserAccount, self.creator_id)
        view_count = self.views.count()
        viewed_by_user = False
        if user_id:
            viewed_by_user = StoryView.query.filter_by(story_id=self.id, user_id=user_id).first() is not None

        return {
            "id": self.id,
            "creator_id": self.creator_id,
            "creator_name": creator.name if creator else "Unknown",
            "creator_username": creator.username if creator else "user",
            "creator_color": creator.profile_color if creator else "#A9523C",
            "text": self.text,
            "bg_color": self.bg_color,
            "emoji": self.emoji,
            "image_url": self.image_url,
            "view_count": view_count,
            "viewed": viewed_by_user,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
        }


class StoryView(db.Model):
    """Track who viewed a story"""
    __tablename__ = 'story_view'
    
    id = db.Column(db.Integer, primary_key=True)
    story_id = db.Column(db.Integer, db.ForeignKey('story.id'), nullable=False, index=True)
    user_id = db.Column(db.Integer, nullable=False, index=True)
    viewed_at = db.Column(db.DateTime, default=utc_now, nullable=False)
    
    # Unique constraint
    __table_args__ = (
        db.UniqueConstraint('story_id', 'user_id', name='unique_story_view'),
        db.Index('idx_story_view_story', 'story_id'),
        db.Index('idx_story_view_user', 'user_id'),
    )


# STUDY GROUPS MODULE

class StudyGroup(db.Model, TimestampMixin):
    """Study group for collaboration"""
    __tablename__ = 'study_group'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False, index=True)
    subject = db.Column(db.String(100), nullable=False, index=True)
    description = db.Column(db.String(500), default="")
    emoji = db.Column(db.String(10), default="📚")
    color = db.Column(db.String(10), default="#3B82F6")
    max_members = db.Column(db.Integer, default=20)
    creator_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    is_active = db.Column(db.Boolean, default=True, index=True)
    is_private = db.Column(db.Boolean, default=False)
    member_count = db.Column(db.Integer, default=0)
    
    members = db.relationship('StudyGroupMember', backref='group', lazy='dynamic', cascade='all, delete-orphan')
    messages = db.relationship('GroupMessage', backref='group', lazy='dynamic', cascade='all, delete-orphan')
    
    
    __table_args__ = (
        db.Index('idx_studygroup_subject', 'subject'),
        db.Index('idx_studygroup_active', 'is_active'),
    )

    def to_dict(self, user_id=None):
        creator = db.session.get(UserAccount, self.creator_id)
        member_count = self.members.count()
        is_member = False
        if user_id:
            is_member = self.members.filter_by(user_id=user_id).first() is not None
        return {
            "id": self.id,
            "name": self.name,
            "subject": self.subject,
            "description": self.description,
            "emoji": self.emoji,
            "color": self.color,
            "max_members": self.max_members,
            "member_count": member_count,
            "is_member": is_member,
            "is_private": self.is_private,
            "creator_id": self.creator_id,
            "creator_name": creator.name if creator else "Unknown",
            "creator_color": creator.profile_color if creator else "#A9523C",
            "is_active": self.is_active,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class StudyGroupMember(db.Model):
    """Membership in a study group"""
    __tablename__ = 'study_group_member'
    
    id = db.Column(db.Integer, primary_key=True)
    group_id = db.Column(db.Integer, db.ForeignKey('study_group.id'), nullable=False, index=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    role = db.Column(db.String(20), default="member")  # admin, moderator, member
    joined_at = db.Column(db.DateTime, default=utc_now, nullable=False)
    
    # Unique constraint
    __table_args__ = (
        db.UniqueConstraint('group_id', 'user_id', name='unique_group_member'),
        db.Index('idx_member_group', 'group_id'),
        db.Index('idx_member_user', 'user_id'),
    )


class GroupMessage(db.Model, TimestampMixin):
    """Message within a study group chat"""
    __tablename__ = 'group_message'
    
    id = db.Column(db.Integer, primary_key=True)
    group_id = db.Column(db.Integer, db.ForeignKey('study_group.id'), nullable=False, index=True)
    sender_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    content = db.Column(db.String(1000), nullable=False)
    message_type = db.Column(db.String(20), default="text")  # text, image, file, system
    media_url = db.Column(db.String(500), nullable=True)
    is_edited = db.Column(db.Boolean, default=False)
    is_deleted = db.Column(db.Boolean, default=False)
    
    
    __table_args__ = (
        db.Index('idx_groupmsg_group_created', 'group_id', 'created_at'),
        db.Index('idx_groupmsg_sender', 'sender_id'),
    )

    def to_dict(self):
        sender = db.session.get(UserAccount, self.sender_id)
        return {
            "id": self.id,
            "group_id": self.group_id,
            "sender_id": self.sender_id,
            "sender_name": sender.name if sender else "Unknown",
            "sender_username": sender.username if sender else "unknown",
            "sender_color": sender.profile_color if sender else "#A9523C",
            "content": self.content,
            "message_type": self.message_type,
            "media_url": self.media_url,
            "is_edited": self.is_edited,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


# COMMUNITY MODULE

class CommunityPost(db.Model, TimestampMixin):
    """Community broadcast/announcement post"""
    __tablename__ = 'community_post'
    
    id = db.Column(db.Integer, primary_key=True)
    channel = db.Column(db.String(50), default="general", index=True)
    author_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    content = db.Column(db.String(1000), nullable=False)
    message_type = db.Column(db.String(20), default="text")
    media_url = db.Column(db.String(500), nullable=True)
    like_count = db.Column(db.Integer, default=0)
    reply_count = db.Column(db.Integer, default=0)
    is_pinned = db.Column(db.Boolean, default=False, index=True)
    is_announcement = db.Column(db.Boolean, default=False)
    
    
    __table_args__ = (
        db.Index('idx_community_channel', 'channel'),
        db.Index('idx_community_created', 'created_at'),
    )

    def to_dict(self):
        author = db.session.get(UserAccount, self.author_id)
        return {
            "id": self.id,
            "channel": self.channel,
            "author_id": self.author_id,
            "author_name": author.name if author else "Unknown",
            "author_username": author.username if author else "unknown",
            "author_color": author.profile_color if author else "#A9523C",
            "content": self.content,
            "message_type": self.message_type,
            "media_url": self.media_url,
            "like_count": self.like_count,
            "reply_count": self.reply_count,
            "is_pinned": self.is_pinned,
            "is_announcement": self.is_announcement,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


# CONFESSIONS MODULE

class Confession(db.Model, TimestampMixin):
    """Anonymous campus confession"""
    __tablename__ = 'confession'
    
    id = db.Column(db.Integer, primary_key=True)
    author_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    content = db.Column(db.String(500), nullable=False)
    category = db.Column(db.String(30), default="general", index=True)
    mood = db.Column(db.String(10), default="😶")
    reaction_count = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True, index=True)
    is_approved = db.Column(db.Boolean, default=True)  # For moderation
    
    reactions = db.relationship('ConfessionReaction', backref='confession', lazy='dynamic', cascade='all, delete-orphan')
    
    
    __table_args__ = (
        db.Index('idx_confession_category', 'category'),
        db.Index('idx_confession_active', 'is_active'),
    )

    def to_dict(self, user_id=None):
        user_reaction = None
        if user_id:
            r = self.reactions.filter_by(user_id=user_id).first()
            if r:
                user_reaction = r.emoji
        return {
            "id": self.id,
            "content": self.content,
            "category": self.category,
            "mood": self.mood,
            "reaction_count": self.reactions.count(),
            "user_reaction": user_reaction,
            "is_anonymous": True,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class ConfessionReaction(db.Model, TimestampMixin):
    """Confession reaction"""
    __tablename__ = 'confession_reaction'
    
    id = db.Column(db.Integer, primary_key=True)
    confession_id = db.Column(db.Integer, db.ForeignKey('confession.id'), nullable=False, index=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    emoji = db.Column(db.String(10), default="❤️")
    
    # Unique constraint
    __table_args__ = (
        db.UniqueConstraint('confession_id', 'user_id', name='unique_confession_reaction'),
        db.Index('idx_reaction_confession', 'confession_id'),
        db.Index('idx_reaction_user', 'user_id'),
    )


# MARKETPLACE MODULE

class MarketplaceListing(db.Model, TimestampMixin):
    """Campus marketplace listing"""
    __tablename__ = 'marketplace_listing'
    
    id = db.Column(db.Integer, primary_key=True)
    seller_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    title = db.Column(db.String(120), nullable=False, index=True)
    description = db.Column(db.String(500), default="")
    price = db.Column(db.Float, nullable=False)
    category = db.Column(db.String(30), default="other", index=True)
    condition = db.Column(db.String(20), default="good")
    image_url = db.Column(db.String(300), default="")
    is_sold = db.Column(db.Boolean, default=False, index=True)
    is_active = db.Column(db.Boolean, default=True, index=True)
    view_count = db.Column(db.Integer, default=0)
    interest_count = db.Column(db.Integer, default=0)
    
    seller = db.relationship('UserAccount', backref='marketplace_listings')
    interests = db.relationship('MarketplaceInterest', backref='listing', lazy='dynamic', cascade='all, delete-orphan')
    
    
    __table_args__ = (
        db.Index('idx_marketplace_category', 'category'),
        db.Index('idx_marketplace_sold', 'is_sold'),
        db.Index('idx_marketplace_active', 'is_active'),
    )

    def to_dict(self, user_id=None):
        is_interested = False
        if user_id:
            is_interested = self.interests.filter_by(user_id=user_id).first() is not None
        return {
            "id": self.id,
            "title": self.title,
            "description": self.description,
            "price": self.price,
            "category": self.category,
            "condition": self.condition,
            "image_url": self.image_url,
            "is_sold": self.is_sold,
            "is_active": self.is_active,
            "interest_count": self.interests.count(),
            "is_interested": is_interested,
            "view_count": self.view_count,
            "seller": {
                "id": self.seller.id,
                "name": self.seller.name,
                "username": self.seller.username,
                "department": self.seller.department,
                "profile_color": self.seller.profile_color,
            } if self.seller else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class MarketplaceInterest(db.Model, TimestampMixin):
    """User interest in a marketplace listing"""
    __tablename__ = 'marketplace_interest'
    
    id = db.Column(db.Integer, primary_key=True)
    listing_id = db.Column(db.Integer, db.ForeignKey('marketplace_listing.id'), nullable=False, index=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    message = db.Column(db.String(200), default="")
    status = db.Column(db.String(20), default="pending")  # pending, contacted, completed
    
    # Unique constraint
    __table_args__ = (
        db.UniqueConstraint('listing_id', 'user_id', name='unique_listing_interest'),
        db.Index('idx_interest_listing', 'listing_id'),
        db.Index('idx_interest_user', 'user_id'),
    )


# EVENTS MODULE

class Event(db.Model, TimestampMixin):
    """Event"""
    __tablename__ = 'event'
    
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False, index=True)
    description = db.Column(db.String(1000), default="")
    date = db.Column(db.String(20), nullable=False, index=True)  # YYYY-MM-DD
    time = db.Column(db.String(20), default="")
    location = db.Column(db.String(200), default="")
    image_url = db.Column(db.String(300), default="")
    organizer_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    max_attendees = db.Column(db.Integer, nullable=True)
    rsvp_count = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True, index=True)
    is_featured = db.Column(db.Boolean, default=False)
    
    organizer = db.relationship('UserAccount', backref='events')
    rsvps = db.relationship('EventRSVP', backref='event', lazy='dynamic', cascade='all, delete-orphan')
    
    
    __table_args__ = (
        db.Index('idx_event_date', 'date'),
        db.Index('idx_event_organizer', 'organizer_id'),
    )

    def to_dict(self, user_id=None):
        user_rsvp = None
        if user_id:
            rsvp = EventRSVP.query.filter_by(event_id=self.id, user_id=user_id).first()
            user_rsvp = rsvp.status if rsvp else None
        
        organizer = db.session.get(UserAccount, self.organizer_id)
        return {
            "id": self.id,
            "title": self.title,
            "description": self.description,
            "date": self.date,
            "time": self.time,
            "location": self.location,
            "image_url": self.image_url,
            "organizer_id": self.organizer_id,
            "organizer_name": organizer.name if organizer else "Unknown",
            "max_attendees": self.max_attendees,
            "rsvp_count": self.rsvp_count,
            "user_rsvp": user_rsvp,
            "is_active": self.is_active,
            "is_featured": self.is_featured,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class EventRSVP(db.Model, TimestampMixin):
    """RSVP to an event"""
    __tablename__ = 'event_rsvp'
    
    id = db.Column(db.Integer, primary_key=True)
    event_id = db.Column(db.Integer, db.ForeignKey('event.id'), nullable=False, index=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    status = db.Column(db.String(20), default="going")  # going, maybe, not_going
    
    # Unique constraint
    __table_args__ = (
        db.UniqueConstraint('event_id', 'user_id', name='unique_event_rsvp'),
        db.Index('idx_rsvp_event', 'event_id'),
        db.Index('idx_rsvp_user', 'user_id'),
    )


class Announcement(db.Model, TimestampMixin):
    """Announcement"""
    __tablename__ = 'announcement'
    
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    content = db.Column(db.String(1000), nullable=False)
    author_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    is_pinned = db.Column(db.Boolean, default=False)
    expires_at = db.Column(db.DateTime, nullable=True)
    
    
    __table_args__ = (
        db.Index('idx_announcement_pinned', 'is_pinned'),
        db.Index('idx_announcement_expires', 'expires_at'),
    )

    def to_dict(self):
        author = db.session.get(UserAccount, self.author_id)
        return {
            "id": self.id,
            "title": self.title,
            "content": self.content,
            "author_id": self.author_id,
            "author_name": author.name if author else "Unknown",
            "is_pinned": self.is_pinned,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


# --- Analytics ---

class ActivityLog(db.Model, TimestampMixin):
    """Activity log entry"""
    __tablename__ = 'activity_log'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    action_type = db.Column(db.String(50), nullable=False, index=True)
    target_type = db.Column(db.String(50), nullable=True)
    target_id = db.Column(db.Integer, nullable=True, index=True)
    action_metadata = db.Column(db.JSON, nullable=True)
    ip_address = db.Column(db.String(45), nullable=True)
    
    
    __table_args__ = (
        db.Index('idx_activity_user_type', 'user_id', 'action_type'),
        db.Index('idx_activity_created', 'created_at'),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "action_type": self.action_type,
            "target_type": self.target_type,
            "target_id": self.target_id,
            "metadata": self.action_metadata,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class ChatHistory(db.Model, TimestampMixin):
    """Chat history with AI chatbot"""
    __tablename__ = 'chat_history'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=True, index=True)
    message = db.Column(db.String(1000), nullable=False)
    response = db.Column(db.Text, nullable=False)
    session_id = db.Column(db.String(100), nullable=True, index=True)
    sentiment = db.Column(db.String(20), nullable=True)
    
    
    __table_args__ = (
        db.Index('idx_chat_user_session', 'user_id', 'session_id'),
        db.Index('idx_chat_created', 'created_at'),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "message": self.message,
            "response": self.response,
            "session_id": self.session_id,
            "sentiment": self.sentiment,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


# ADMIN & MODERATION

class AdminLog(db.Model, TimestampMixin):
    """Admin action logging"""
    __tablename__ = 'admin_log'
    
    id = db.Column(db.Integer, primary_key=True)
    admin_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    action = db.Column(db.String(100), nullable=False)
    target_type = db.Column(db.String(50), nullable=True)
    target_id = db.Column(db.Integer, nullable=True)
    reason = db.Column(db.String(500), nullable=True)
    
    admin = db.relationship('UserAccount', backref='admin_logs')
    
    
    __table_args__ = (
        db.Index('idx_adminlog_admin', 'admin_id'),
        db.Index('idx_adminlog_created', 'created_at'),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "admin_id": self.admin_id,
            "admin_name": self.admin.name if self.admin else "Unknown",
            "action": self.action,
            "target_type": self.target_type,
            "target_id": self.target_id,
            "reason": self.reason,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class ReportedContent(db.Model, TimestampMixin):
    """Reported content for moderation"""
    __tablename__ = 'reported_content'
    
    id = db.Column(db.Integer, primary_key=True)
    reporter_id = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=False, index=True)
    content_type = db.Column(db.String(50), nullable=False, index=True)  # post, comment, user, confession
    content_id = db.Column(db.Integer, nullable=False, index=True)
    reason = db.Column(db.String(500), nullable=False)
    status = db.Column(db.String(20), default="pending", index=True)  # pending, reviewed, actioned
    reviewed_by = db.Column(db.Integer, db.ForeignKey('user_account.id'), nullable=True)
    reviewed_at = db.Column(db.DateTime, nullable=True)
    
    
    __table_args__ = (
        db.Index('idx_report_content', 'content_type', 'content_id'),
        db.Index('idx_report_status', 'status'),
    )

    def to_dict(self):
        reporter = db.session.get(UserAccount, self.reporter_id)
        reviewer = db.session.get(UserAccount, self.reviewed_by) if self.reviewed_by else None
        return {
            "id": self.id,
            "reporter_id": self.reporter_id,
            "reporter_name": reporter.name if reporter else "Unknown",
            "content_type": self.content_type,
            "content_id": self.content_id,
            "reason": self.reason,
            "status": self.status,
            "reviewed_by": self.reviewed_by,
            "reviewer_name": reviewer.name if reviewer else None,
            "reviewed_at": self.reviewed_at.isoformat() if self.reviewed_at else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
