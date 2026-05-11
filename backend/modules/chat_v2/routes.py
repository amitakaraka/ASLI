"""
Enhanced AI Chatbot with OpenAI Integration
Production-ready chatbot with context awareness and campus knowledge
"""
from flask import Blueprint, request, jsonify, current_app
from database.models import db, ChatHistory, UserAccount
from modules.auth.jwt_utils import token_required, optional_token
from services.notification_service import send_notification
import logging
import re
import json
from datetime import datetime
from utils.time import utc_now

logger = logging.getLogger(__name__)

chat_v2_bp = Blueprint('chat_v2', __name__, url_prefix='/api/chat')

# Import knowledge base
from knowledge_base import COLLEGE_QA


class AIChatbot:
    """Advanced AI Chatbot with hybrid approach"""
    
    def __init__(self):
        self.knowledge_base = COLLEGE_QA
        self.openai_available = False
        self.api_key = None
        
    def initialize(self, app):
        """Initialize with Flask app config"""
        self.api_key = app.config.get('OPENAI_API_KEY')
        self.openai_available = bool(self.api_key and self.api_key != 'your-openai-api-key-here')
        
        if self.openai_available:
            try:
                import openai
                openai.api_key = self.api_key
                logger.info("✅ OpenAI integration enabled")
            except Exception as e:
                logger.warning(f"❌ OpenAI initialization failed: {e}")
                self.openai_available = False
        else:
            logger.info("ℹ️ OpenAI not configured - using rule-based responses")
    
    def get_response(self, query, user_id=None, conversation_history=None):
        """
        Get chatbot response using hybrid approach
        
        Args:
            query: User's question
            user_id: Optional user ID for personalization
            conversation_history: List of previous messages for context
        
        Returns:
            dict with answer, confidence, category, and metadata
        """
        # Step 1: Try knowledge base matching (fast & accurate for known questions)
        kb_result = self._match_knowledge_base(query)
        
        if kb_result['confidence'] >= 80:
            # High confidence match from knowledge base
            self._save_chat_history(user_id, query, kb_result['answer'], 'knowledge_base')
            return kb_result
        
        # Step 2: Use OpenAI for complex queries (if available)
        if self.openai_available:
            try:
                ai_result = self._get_openai_response(query, conversation_history, kb_result)
                self._save_chat_history(user_id, query, ai_result['answer'], 'openai')
                return ai_result
            except Exception as e:
                logger.error(f"OpenAI error: {e}")
                # Fallback to knowledge base with lower confidence
                kb_result['confidence'] = max(kb_result['confidence'], 30)
                kb_result['metadata']['fallback'] = True
        
        # Step 3: Fallback response
        fallback_result = self._get_fallback_response(query, kb_result)
        self._save_chat_history(user_id, query, fallback_result['answer'], 'fallback')
        return fallback_result
    
    def _match_knowledge_base(self, query):
        """Match query against knowledge base using fuzzy matching"""
        query_lower = query.lower().strip()
        best_match = None
        best_score = 0
        
        for item in self.knowledge_base:
            # Check keywords
            keyword_score = sum(1 for kw in item['keywords'] if kw in query_lower)
            
            # Check patterns
            pattern_score = sum(1 for pattern in item['patterns'] if pattern in query_lower)
            
            # Calculate total score
            score = (keyword_score * 2) + (pattern_score * 5)
            
            # Bonus for exact matches
            if query_lower in [p for p in item['patterns']]:
                score += 50
            
            if score > best_score:
                best_score = score
                best_match = item
        
        if best_match and best_score > 0:
            confidence = min(95, 50 + (best_score * 5))
            return {
                'answer': best_match['answer'],
                'confidence': int(confidence),
                'category': 'knowledge_base',
                'metadata': {
                    'matched_keywords': [kw for kw in best_match['keywords'] if kw in query_lower],
                    'source': 'AU Knowledge Base'
                }
            }
        
        return {
            'answer': "I'm not sure about that. Let me help you with something else!",
            'confidence': 0,
            'category': 'unknown',
            'metadata': {'source': 'No Match'}
        }
    
    def _get_openai_response(self, query, conversation_history, kb_context):
        """Get response from OpenAI GPT"""
        import openai
        
        # Build context-aware prompt
        system_prompt = """You are Asli, a friendly and knowledgeable AI assistant for Andhra University (AU).
        
Key facts about AU:
- Founded: 1926 (Celebrating Centenary 2025-26!)
- Location: Visakhapatnam, Andhra Pradesh, India
- NAAC A++ accredited
- NIRF Rank 4 (State Public Universities)

Your role:
- Help students with admissions, exams, fees, hostels, placements, etc.
- Be friendly, concise, and accurate
- Use emojis sparingly to make responses engaging
- If unsure, direct students to official AU website: www.andhrauniversity.edu.in
- For urgent matters, suggest contacting AU directly

Knowledge Base Context (use this if relevant):
"""
        if kb_context['confidence'] > 0:
            system_prompt += f"\n{kb_context['answer'][:500]}...\n"
        
        system_prompt += "\n\nRespond in a helpful, conversational tone. Keep answers under 200 words unless explaining complex topics."
        
        # Build messages array
        messages = [
            {"role": "system", "content": system_prompt}
        ]
        
        # Add conversation history for context (last 5 messages)
        if conversation_history:
            for msg in conversation_history[-5:]:
                messages.append({"role": msg['role'], "content": msg['content']})
        
        # Add current query
        messages.append({"role": "user", "content": query})
        
        # Call OpenAI API
        response = openai.ChatCompletion.create(
            model="gpt-3.5-turbo",
            messages=messages,
            max_tokens=500,
            temperature=0.7,
            top_p=1,
            frequency_penalty=0,
            presence_penalty=0,
        )
        
        answer = response.choices[0].message.content.strip()
        
        # Estimate confidence based on response quality
        confidence = 75  # Base confidence for AI responses
        if len(answer) > 50 and '?' not in answer:
            confidence += 10  # Confident response
        if any(word in answer.lower() for word in ['au', 'university', 'andhra']):
            confidence += 5  # Contextually relevant
        
        return {
            'answer': answer,
            'confidence': min(confidence, 90),
            'category': 'ai_assistant',
            'metadata': {
                'model': 'gpt-3.5-turbo',
                'source': 'OpenAI',
                'tokens_used': response.usage.total_tokens
            }
        }
    
    def _get_fallback_response(self, query, kb_result):
        """Generate fallback response when no good match found"""
        
        # Detect intent from query
        query_lower = query.lower()
        
        # Greeting detection
        if any(greet in query_lower for greet in ['hi', 'hello', 'hey', 'greetings', 'namaste']):
            return {
                'answer': "Hello! 👋 I'm Asli, your Andhra University assistant. How can I help you today? Ask me about admissions, exams, fees, hostels, or anything related to AU!",
                'confidence': 90,
                'category': 'greeting',
                'metadata': {'intent': 'greeting'}
            }
        
        # Thanks detection
        if any(thank in query_lower for thank in ['thank', 'thanks', 'thank you', 'ty']):
            return {
                'answer': "You're welcome! 😊 Feel free to ask if you have more questions about Andhra University. I'm here to help!",
                'confidence': 95,
                'category': 'gratitude',
                'metadata': {'intent': 'thanks'}
            }
        
        # Help request
        if 'help' in query_lower:
            return {
                'answer': "🎓 I can help you with:\n\n"
                         "• 📋 Admissions & Eligibility\n"
                         "• 📅 Exam schedules & Results\n"
                         "• 💰 Fee payment & Scholarships\n"
                         "• 🏠 Hostel facilities\n"
                         "• 📚 Library resources\n"
                         "• 💼 Placements & Career\n"
                         "• 📜 Certificates & Documents\n"
                         "• 🎉 Centenary celebrations\n"
                         "• 🔗 Important links & contacts\n\n"
                         "Just ask me anything about Andhra University!",
                'confidence': 85,
                'category': 'help',
                'metadata': {'intent': 'help_request'}
            }
        
        # Low confidence knowledge base match
        if kb_result['confidence'] > 0:
            return {
                'answer': f"Here's what I found:\n\n{kb_result['answer']}\n\n"
                         f"📌 For more details, visit: www.andhrauniversity.edu.in",
                'confidence': max(30, kb_result['confidence'] - 10),
                'category': 'knowledge_base_partial',
                'metadata': {'source': 'Partial Match'}
            }
        
        # Default fallback
        return {
            'answer': "I'm not sure I understand that question. 🤔\n\n"
                     "Try asking about:\n"
                     "• Admissions process\n"
                     "• Exam dates\n"
                     "• Fee structure\n"
                     "• Hostel facilities\n"
                     "• Library resources\n\n"
                     "Or visit www.andhrauniversity.edu.in for detailed information!",
            'confidence': 20,
            'category': 'fallback',
            'metadata': {'intent': 'unknown'}
        }
    
    def _save_chat_history(self, user_id, query, response, source):
        """Save chat interaction to database"""
        try:
            if user_id:
                history = ChatHistory(
                    user_id=user_id,
                    message=query,
                    response=response,
                    session_id=utc_now().strftime('%Y-%m-%d'),
                    sentiment=self._analyze_sentiment(query)
                )
                db.session.add(history)
                db.session.commit()
        except Exception as e:
            logger.error(f"Failed to save chat history: {e}")
    
    def _analyze_sentiment(self, text):
        """Simple sentiment analysis"""
        positive_words = ['good', 'great', 'excellent', 'happy', 'thank', 'awesome', 'nice', 'love']
        negative_words = ['bad', 'terrible', 'awful', 'sad', 'angry', 'hate', 'worst', 'poor']
        
        text_lower = text.lower()
        pos_count = sum(1 for word in positive_words if word in text_lower)
        neg_count = sum(1 for word in negative_words if word in text_lower)
        
        if pos_count > neg_count:
            return 'positive'
        elif neg_count > pos_count:
            return 'negative'
        return 'neutral'
    
    def get_suggestions(self, prefix):
        """Get query suggestions based on prefix"""
        if len(prefix) < 2:
            return []
        
        suggestions = []
        prefix_lower = prefix.lower()
        
        # Common AU-related suggestions
        common_suggestions = [
            "Admission process",
            "Admission eligibility",
            "Exam schedule",
            "Exam results",
            "Fee structure",
            "Fee payment online",
            "Hostel facilities",
            "Hostel admission",
            "Library timing",
            "Library e-resources",
            "Placement statistics",
            "Placement companies",
            "Certificate application",
            "Transcript process",
            "MOOCS registration",
            "Centenary events",
            "Sports facilities",
            "Scholarship available",
            "Contact information",
            "Campus facilities"
        ]
        
        for suggestion in common_suggestions:
            if suggestion.lower().startswith(prefix_lower):
                suggestions.append(suggestion)
                if len(suggestions) >= 5:
                    break
        
        return suggestions


# Global chatbot instance
chatbot = AIChatbot()


@chat_v2_bp.route('/message', methods=['POST'])
@optional_token
def send_message(user_id):
    """
    Send message to AI chatbot
    
    Request body:
        - message: User's query (required)
        - conversation_id: Optional conversation ID for context
        - save: Whether to save to history (default: True)
    """
    try:
        data = request.get_json()
        
        if not data or 'message' not in data:
            return jsonify({
                'success': False,
                'error': 'Message is required',
                'error_code': 'VALIDATION_MISSING_MESSAGE'
            }), 400
        
        message = data['message'].strip()
        conversation_id = data.get('conversation_id')
        save_history = data.get('save', True)
        
        if not message:
            return jsonify({
                'success': False,
                'error': 'Message cannot be empty',
                'error_code': 'VALIDATION_EMPTY_MESSAGE'
            }), 400
        
        # Get conversation history if conversation_id provided
        conversation_history = None
        if conversation_id and user_id:
            # Fetch last 10 messages from history
            from database.models import ChatHistory
            history = ChatHistory.query.filter_by(
                user_id=user_id
            ).order_by(ChatHistory.created_at.desc()).limit(10).all()
            
            conversation_history = []
            for h in reversed(history):
                conversation_history.append({
                    'role': 'user',
                    'content': h.message
                })
                conversation_history.append({
                    'role': 'assistant',
                    'content': h.response
                })
        
        # Get chatbot response
        result = chatbot.get_response(
            query=message,
            user_id=user_id if save_history else None,
            conversation_history=conversation_history
        )
        
        response_data = {
            'success': True,
            'query': message,
            'answer': result['answer'],
            'confidence': result['confidence'],
            'category': result['category'],
            'metadata': result.get('metadata', {}),
            'timestamp': utc_now().isoformat()
        }
        
        # Add user info if logged in
        if user_id:
            user = db.session.get(UserAccount, user_id)
            if user:
                response_data['personalized'] = True
        
        return jsonify(response_data)
    
    except Exception as e:
        logger.error(f"Chat message error: {str(e)}", exc_info=True)
        return jsonify({
            'success': False,
            'error': 'Failed to process message',
            'error_code': 'CHAT_PROCESSING_ERROR'
        }), 500


@chat_v2_bp.route('/suggestions', methods=['GET'])
def get_suggestions():
    """Get query suggestions based on prefix"""
    try:
        prefix = request.args.get('q', '')
        
        if len(prefix) < 2:
            return jsonify({
                'success': True,
                'suggestions': []
            })
        
        suggestions = chatbot.get_suggestions(prefix)
        
        return jsonify({
            'success': True,
            'suggestions': suggestions,
            'count': len(suggestions)
        })
    
    except Exception as e:
        logger.error(f"Suggestions error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to get suggestions',
            'error_code': 'SUGGESTIONS_ERROR'
        }), 500


@chat_v2_bp.route('/history', methods=['GET'])
@token_required
def get_chat_history(user_id):
    """Get user's chat history"""
    try:
        from database.models import ChatHistory
        
        page = request.args.get('page', 1, type=int)
        limit = min(request.args.get('limit', 20, type=int), 50)
        session_id = request.args.get('session_id')
        
        query = ChatHistory.query.filter_by(user_id=user_id)
        
        if session_id:
            query = query.filter_by(session_id=session_id)
        
        history = query.order_by(
            ChatHistory.created_at.desc()
        ).paginate(page=page, per_page=limit, error_out=False)
        
        return jsonify({
            'success': True,
            'count': len(history.items),
            'page': page,
            'total_pages': history.pages,
            'data': [{
                'id': h.id,
                'message': h.message,
                'response': h.response,
                'sentiment': h.sentiment,
                'session_id': h.session_id,
                'created_at': h.created_at.isoformat()
            } for h in history.items]
        })
    
    except Exception as e:
        logger.error(f"Chat history error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to fetch history',
            'error_code': 'HISTORY_FETCH_ERROR'
        }), 500


@chat_v2_bp.route('/clear-history', methods=['POST'])
@token_required
def clear_chat_history(user_id):
    """Clear user's chat history"""
    try:
        from database.models import ChatHistory
        
        session_id = request.json.get('session_id') if request.json else None
        
        if session_id:
            ChatHistory.query.filter_by(
                user_id=user_id,
                session_id=session_id
            ).delete()
        else:
            ChatHistory.query.filter_by(user_id=user_id).delete()
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Chat history cleared successfully'
        })
    
    except Exception as e:
        logger.error(f"Clear history error: {str(e)}")
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': 'Failed to clear history',
            'error_code': 'CLEAR_HISTORY_ERROR'
        }), 500


@chat_v2_bp.route('/stats', methods=['GET'])
@token_required
def get_chat_stats(user_id):
    """Get user's chat statistics"""
    try:
        from database.models import ChatHistory
        from sqlalchemy import func
        
        total_chats = ChatHistory.query.filter_by(user_id=user_id).count()
        
        # Get sentiment distribution
        sentiments = db.session.query(
            ChatHistory.sentiment,
            func.count(ChatHistory.id)
        ).filter_by(user_id=user_id).group_by(ChatHistory.sentiment).all()
        
        sentiment_counts = {s[0]: s[1] for s in sentiments}
        
        # Get most recent chat
        last_chat = ChatHistory.query.filter_by(user_id=user_id)\
            .order_by(ChatHistory.created_at.desc()).first()
        
        return jsonify({
            'success': True,
            'stats': {
                'total_chats': total_chats,
                'sentiments': sentiment_counts,
                'last_chat_at': last_chat.created_at.isoformat() if last_chat else None
            }
        })
    
    except Exception as e:
        logger.error(f"Chat stats error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to fetch stats',
            'error_code': 'STATS_ERROR'
        }), 500


# Initialize chatbot on blueprint registration
def init_chatbot(app):
    """Initialize chatbot with Flask app"""
    chatbot.initialize(app)
    logger.info("✅ AI Chatbot initialized")


def chatbot_status():
    """Return chatbot readiness details for health checks."""
    return {
        'ready': bool(chatbot.knowledge_base),
        'mode': 'openai' if chatbot.openai_available else 'rule_based',
        'knowledge_base_items': len(chatbot.knowledge_base),
    }
