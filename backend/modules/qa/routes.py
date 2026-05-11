"""
Q&A Module Routes — Community Questions & Answers
Now with JWT auth to track who asked/answered
"""
from flask import Blueprint, request, jsonify
from database.models import db, Question, Answer, UserAccount
from modules.auth.jwt_utils import token_required
from services.notification_service import notify_answer

qa_bp = Blueprint('qa', __name__, url_prefix='/api')


@qa_bp.route('/questions', methods=['POST'])
@token_required
def add_question(user_id):
    data = request.json
    if not data or 'text' not in data:
        return jsonify({'success': False, 'error': 'Question text is required'}), 400
    q = Question(text=data['text'], user_id=user_id)
    db.session.add(q)
    db.session.commit()
    return jsonify({'success': True, 'message': 'Question added', 'data': _question_dict(q)}), 201


@qa_bp.route('/questions', methods=['GET'])
def get_questions():
    questions = Question.query.order_by(Question.created_at.desc()).all()
    return jsonify({
        'success': True,
        'count': len(questions),
        'data': [_question_dict(q) for q in questions],
    })


@qa_bp.route('/questions/<int:question_id>', methods=['GET'])
def get_question(question_id):
    question = db.session.get(Question, question_id)
    if not question:
        return jsonify({'success': False, 'error': 'Question not found'}), 404
    return jsonify({'success': True, 'data': _question_dict(question)})


@qa_bp.route('/answers', methods=['POST'])
@token_required
def add_answer(user_id):
    data = request.json
    if not data or 'question_id' not in data or 'text' not in data:
        return jsonify({'success': False, 'error': 'question_id and text required'}), 400
    answer = Answer(question_id=data['question_id'], text=data['text'], user_id=user_id)
    db.session.add(answer)
    db.session.commit()
    # Notify the question asker
    question = db.session.get(Question, data['question_id'])
    if question and question.user_id:
        notify_answer(user_id, question.user_id, question.text)
    return jsonify({'success': True, 'message': 'Answer added', 'data': _answer_dict(answer)}), 201


@qa_bp.route('/answers/<int:question_id>', methods=['GET'])
def get_answers(question_id):
    answers = Answer.query.filter_by(question_id=question_id).order_by(Answer.created_at.asc()).all()
    return jsonify({
        'success': True,
        'count': len(answers),
        'data': [_answer_dict(a) for a in answers],
    })


def _question_dict(q):
    """Enrich question with asker info"""
    d = q.to_dict()
    if q.user_id:
        user = db.session.get(UserAccount, q.user_id)
        if user:
            d['user_name'] = user.name
            d['username'] = user.username
            d['profile_color'] = user.profile_color
    return d


def _answer_dict(a):
    """Enrich answer with answerer info"""
    d = a.to_dict()
    if a.user_id:
        user = db.session.get(UserAccount, a.user_id)
        if user:
            d['user_name'] = user.name
            d['username'] = user.username
            d['profile_color'] = user.profile_color
    return d
