"""
Chat Module Routes — AI Chatbot
"""
from flask import Blueprint, request, jsonify
from database.models import db, Question
from nlp_processor import get_chatbot_response, get_suggestions

chat_bp = Blueprint('chat', __name__, url_prefix='/api')


@chat_bp.route('/chat', methods=['POST'])
def chat():
    data = request.json
    if not data or 'message' not in data:
        return jsonify({'success': False, 'error': 'Message is required'}), 400

    query = data['message']
    response = get_chatbot_response(query)

    if data.get('save_question', True):
        q = Question(text=query)
        db.session.add(q)
        db.session.commit()

    return jsonify({
        'success': True,
        'query': query,
        'answer': response['answer'],
        'confidence': response['confidence'],
        'category': response['category']
    })


@chat_bp.route('/suggestions', methods=['GET'])
def suggestions():
    query = request.args.get('q', '')
    if len(query) < 2:
        return jsonify({'success': True, 'suggestions': []})
    return jsonify({'success': True, 'suggestions': get_suggestions(query)})
