from flask_sqlalchemy import SQLAlchemy
from utils.time import utc_now

db = SQLAlchemy()

class Question(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    text = db.Column(db.String(500), nullable=False)
    created_at = db.Column(db.DateTime, default=utc_now)
    
    def to_dict(self):
        return {
            "id": self.id,
            "text": self.text,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }

class Answer(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    question_id = db.Column(db.Integer, nullable=False)
    text = db.Column(db.String(500), nullable=False)
    created_at = db.Column(db.DateTime, default=utc_now)
    
    def to_dict(self):
        return {
            "id": self.id,
            "question_id": self.question_id,
            "text": self.text,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }


# COLLX MODELS

class CollxUser(db.Model):
    """Campus social network user profile"""
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    username = db.Column(db.String(50), unique=True, nullable=False)
    bio = db.Column(db.String(160), default="")
    department = db.Column(db.String(100), default="")
    year = db.Column(db.String(20), default="")
    profile_color = db.Column(db.String(10), default="#4F46E5")
    follower_count = db.Column(db.Integer, default=0)
    following_count = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=utc_now)

    posts = db.relationship('CollxPost', backref='author', lazy='dynamic')

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "username": self.username,
            "bio": self.bio,
            "department": self.department,
            "year": self.year,
            "profile_color": self.profile_color,
            "follower_count": self.follower_count,
            "following_count": self.following_count,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class CollxPost(db.Model):
    """A microblog post (like a tweet)"""
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('collx_user.id'), nullable=False)
    content = db.Column(db.String(280), nullable=False)
    image_url = db.Column(db.String(500), default="")
    like_count = db.Column(db.Integer, default=0)
    reply_count = db.Column(db.Integer, default=0)
    repost_count = db.Column(db.Integer, default=0)
    hashtags = db.Column(db.String(500), default="")
    created_at = db.Column(db.DateTime, default=utc_now)

    replies = db.relationship('CollxReply', backref='post', lazy='dynamic')

    def to_dict(self):
        author = db.session.get(CollxUser, self.user_id)
        return {
            "id": self.id,
            "user_id": self.user_id,
            "author_name": author.name if author else "Unknown",
            "author_username": author.username if author else "unknown",
            "author_color": author.profile_color if author else "#4F46E5",
            "content": self.content,
            "image_url": self.image_url,
            "like_count": self.like_count,
            "reply_count": self.reply_count,
            "repost_count": self.repost_count,
            "hashtags": self.hashtags,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class CollxLike(db.Model):
    """Like on a post"""
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('collx_user.id'), nullable=False)
    post_id = db.Column(db.Integer, db.ForeignKey('collx_post.id'), nullable=False)
    created_at = db.Column(db.DateTime, default=utc_now)

    __table_args__ = (db.UniqueConstraint('user_id', 'post_id'),)


class CollxReply(db.Model):
    """Reply to a post"""
    id = db.Column(db.Integer, primary_key=True)
    post_id = db.Column(db.Integer, db.ForeignKey('collx_post.id'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('collx_user.id'), nullable=False)
    content = db.Column(db.String(280), nullable=False)
    created_at = db.Column(db.DateTime, default=utc_now)

    def to_dict(self):
        author = db.session.get(CollxUser, self.user_id)
        return {
            "id": self.id,
            "post_id": self.post_id,
            "user_id": self.user_id,
            "author_name": author.name if author else "Unknown",
            "author_username": author.username if author else "unknown",
            "content": self.content,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class CollxFollow(db.Model):
    """Follow relationship"""
    id = db.Column(db.Integer, primary_key=True)
    follower_id = db.Column(db.Integer, db.ForeignKey('collx_user.id'), nullable=False)
    following_id = db.Column(db.Integer, db.ForeignKey('collx_user.id'), nullable=False)
    created_at = db.Column(db.DateTime, default=utc_now)

    __table_args__ = (db.UniqueConstraint('follower_id', 'following_id'),)
