"""
Notification Service — Generates notifications for all social events
Covers: Likes, Replies, Follows, Q&A Answers, DMs, Marketplace Interest
"""
from database.models import db, Notification, UserAccount


def notify_like(actor_id, post_owner_id, post_id):
    """Notify when someone likes your post"""
    if actor_id == post_owner_id:
        return  # Don't notify self
    actor = db.session.get(UserAccount, actor_id)
    if not actor:
        return
    notif = Notification(
        user_id=post_owner_id,
        type='like',
        title=f'{actor.name} liked your post',
        body='Tap to view',
        actor_id=actor_id,
        post_id=post_id,
    )
    db.session.add(notif)
    db.session.commit()


def notify_reply(actor_id, post_owner_id, post_id, reply_text):
    """Notify when someone replies to your post"""
    if actor_id == post_owner_id:
        return
    actor = db.session.get(UserAccount, actor_id)
    if not actor:
        return
    notif = Notification(
        user_id=post_owner_id,
        type='reply',
        title=f'{actor.name} replied to your post',
        body=reply_text[:100],
        actor_id=actor_id,
        post_id=post_id,
    )
    db.session.add(notif)
    db.session.commit()


def notify_follow(actor_id, target_id):
    """Notify when someone follows you"""
    if actor_id == target_id:
        return
    actor = db.session.get(UserAccount, actor_id)
    if not actor:
        return
    notif = Notification(
        user_id=target_id,
        type='follow',
        title=f'{actor.name} started following you',
        body=f'@{actor.username}',
        actor_id=actor_id,
    )
    db.session.add(notif)
    db.session.commit()


def notify_answer(actor_id, question_owner_id, question_text):
    """Notify when someone answers your question"""
    if actor_id == question_owner_id:
        return
    if not question_owner_id:
        return  # Question has no owner (legacy data)
    actor = db.session.get(UserAccount, actor_id)
    if not actor:
        return
    notif = Notification(
        user_id=question_owner_id,
        type='answer',
        title=f'{actor.name} answered your question',
        body=question_text[:100] if question_text else 'Tap to view',
        actor_id=actor_id,
    )
    db.session.add(notif)
    db.session.commit()


def notify_dm(sender_id, receiver_id, message_text):
    """Notify when someone sends you a DM"""
    if sender_id == receiver_id:
        return
    sender = db.session.get(UserAccount, sender_id)
    if not sender:
        return
    notif = Notification(
        user_id=receiver_id,
        type='dm',
        title=f'{sender.name} sent you a message',
        body=message_text[:80] if message_text else 'New message',
        actor_id=sender_id,
    )
    db.session.add(notif)
    db.session.commit()


def notify_marketplace_interest(buyer_id, seller_id, listing_title):
    """Notify seller when someone is interested in their listing"""
    if buyer_id == seller_id:
        return
    buyer = db.session.get(UserAccount, buyer_id)
    if not buyer:
        return
    notif = Notification(
        user_id=seller_id,
        type='marketplace',
        title=f'{buyer.name} is interested in "{listing_title[:40]}"',
        body='Check your marketplace listings',
        actor_id=buyer_id,
    )
    db.session.add(notif)
    db.session.commit()


def notify_system(user_id, title, body=""):
    """System notification (events, announcements)"""
    notif = Notification(
        user_id=user_id,
        type='system',
        title=title,
        body=body,
    )
    db.session.add(notif)
    db.session.commit()


def send_notification(user_id, notif_type, title, body="", actor_id=None, post_id=None):
    """
    Generic notification sender — used by modules that need a simple interface.
    For specific event types, prefer the dedicated notify_* helpers above.
    """
    try:
        notif = Notification(
            user_id=user_id,
            type=notif_type,
            title=title,
            body=body or "",
            actor_id=actor_id,
            post_id=post_id,
        )
        db.session.add(notif)
        db.session.commit()
        return notif
    except Exception as e:
        db.session.rollback()
        return None
