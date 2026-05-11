from flask_socketio import emit, join_room, leave_room
from flask import request
import json
from datetime import datetime
from utils.time import utc_now

connected_users = {}


def register_socket_handlers(socketio):

    @socketio.on("connect")
    def handle_connect():
        print(f"Client connected: {request.sid}")
        emit("connected", {"status": "ok"})

    @socketio.on("disconnect")
    def handle_disconnect():
        sid = request.sid
        if sid in connected_users:
            user_id = connected_users[sid]
            del connected_users[sid]
            print(f"User {user_id} disconnected")
        print(f"Client disconnected: {sid}")

    @socketio.on("authenticate")
    def handle_auth(data):
        user_id = data.get("user_id")
        if user_id:
            connected_users[request.sid] = user_id
            join_room(f"user_{user_id}")
            emit("authenticated", {"status": "ok", "user_id": user_id})
            print(f"User {user_id} authenticated")
        else:
            emit("error", {"message": "Invalid authentication"})

    @socketio.on("join")
    def handle_join(data):
        room = data.get("room")
        if room:
            join_room(room)
            emit("joined", {"room": room})

    @socketio.on("leave")
    def handle_leave(data):
        room = data.get("room")
        if room:
            leave_room(room)
            emit("left", {"room": room})

    @socketio.on("typing")
    def handle_typing(data):
        to_user = data.get("to_user")
        conversation_id = data.get("conversation_id")
        is_typing = data.get("is_typing", False)

        if to_user:
            emit(
                "typing",
                {
                    "is_typing": is_typing,
                    "conversation_id": conversation_id,
                    "from_user": connected_users.get(request.sid),
                },
                room=f"user_{to_user}",
            )

    @socketio.on("private_message")
    def handle_private_message(data):
        to_user = data.get("to")
        content = data.get("content")
        from_user = connected_users.get(request.sid)

        if to_user and content:
            message_data = {
                "from": from_user,
                "content": content,
                "timestamp": utc_now().isoformat(),
                "conversation_id": data.get("conversation_id"),
            }
            emit("new_message", message_data, room=f"user_{to_user}")
            emit("message_sent", message_data)

    @socketio.on("mark_read")
    def handle_mark_read(data):
        conversation_id = data.get("conversation_id")
        to_user = data.get("to_user")

        if to_user:
            emit(
                "read_receipt",
                {
                    "conversation_id": conversation_id,
                    "read_by": connected_users.get(request.sid),
                    "read_at": utc_now().isoformat(),
                },
                room=f"user_{to_user}",
            )

    @socketio.on("ping")
    def handle_ping():
        emit("pong", {"timestamp": utc_now().isoformat()})

    @socketio.on("notification_subscribe")
    def handle_notification_subscribe(data):
        user_id = data.get("user_id")
        if user_id:
            join_room(f"notifications_{user_id}")
            emit("subscribed", {"channel": f"notifications_{user_id}"})


def send_notification(socketio, user_id, notification_data):
    socketio.emit("notification", notification_data, room=f"user_{user_id}")


def send_to_room(socketio, room, event, data):
    socketio.emit(event, data, room=room)
