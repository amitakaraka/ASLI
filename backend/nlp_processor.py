"""
Enhanced NLP Processor for College Chatbot
Uses keyword matching, pattern recognition, and fuzzy matching to understand student queries
"""

import re
from knowledge_base import COLLEGE_QA, GREETINGS, THANKS, DEFAULT_RESPONSE


def preprocess_text(text):
    """Clean and normalize input text"""
    text = text.lower().strip()
    text = re.sub(r'[^\w\s]', '', text)
    text = re.sub(r'\s+', ' ', text)
    return text


def levenshtein_ratio(s1, s2):
    """Simple similarity ratio between two strings"""
    if not s1 or not s2:
        return 0.0
    len1, len2 = len(s1), len(s2)
    if len1 == 0 or len2 == 0:
        return 0.0
    # Quick check: if one contains the other
    if s1 in s2 or s2 in s1:
        return 0.85
    # Word overlap ratio
    words1 = set(s1.split())
    words2 = set(s2.split())
    if not words1 or not words2:
        return 0.0
    intersection = words1 & words2
    union = words1 | words2
    return len(intersection) / len(union) if union else 0.0


def calculate_match_score(query, qa_item):
    """
    Calculate how well a query matches a Q&A item
    Returns a score from 0 to 100
    """
    query = preprocess_text(query)
    query_words = set(query.split())
    score = 0

    # 1. Exact keyword match (15 points each, max 45)
    keyword_matches = 0
    for keyword in qa_item['keywords']:
        kw = keyword.lower()
        if kw in query:
            keyword_matches += 1
        elif any(levenshtein_ratio(kw, w) >= 0.8 for w in query_words):
            keyword_matches += 0.7  # Partial credit for fuzzy match
    score += min(keyword_matches * 15, 45)

    # 2. Pattern match (30 points for best pattern)
    best_pattern_score = 0
    for pattern in qa_item['patterns']:
        pattern_clean = preprocess_text(pattern)
        pattern_words = set(pattern_clean.split())
        if not pattern_words:
            continue
        overlap = len(pattern_words & query_words)
        ratio = overlap / len(pattern_words)
        if ratio >= 0.5:
            pattern_score = ratio * 30
            best_pattern_score = max(best_pattern_score, pattern_score)
    score += best_pattern_score

    # 3. Bonus: if query is very similar to a pattern (fuzzy full match)
    for pattern in qa_item['patterns']:
        sim = levenshtein_ratio(query, preprocess_text(pattern))
        if sim >= 0.7:
            score += 20
            break

    return min(int(score), 100)


def is_greeting(query):
    """Check if the query is a greeting"""
    query = preprocess_text(query)
    for keyword in GREETINGS['keywords']:
        if keyword in query.split():
            return True
    return False


def is_thanks(query):
    """Check if the query is a thank you"""
    query = preprocess_text(query)
    query_words = query.split()
    for keyword in THANKS['keywords']:
        # Check whole word match, or check if keyword is contained as a word
        if keyword in query_words:
            return True
        # Also check multi-word keywords like "thank you"
        if ' ' in keyword and keyword in query:
            return True
    return False


def get_chatbot_response(query):
    """
    Main function to get chatbot response for a query
    Uses NLP-based matching to find the best answer
    """
    if not query or len(query.strip()) < 2:
        return {
            "answer": "Please enter a valid question.",
            "confidence": 0,
            "category": "error"
        }

    # Check for greetings first
    if is_greeting(query):
        return {
            "answer": GREETINGS['answer'],
            "confidence": 100,
            "category": "greeting"
        }

    # Check for thanks
    if is_thanks(query):
        return {
            "answer": THANKS['answer'],
            "confidence": 100,
            "category": "thanks"
        }

    # Find best matching Q&A
    best_match = None
    best_score = 0

    for qa_item in COLLEGE_QA:
        score = calculate_match_score(query, qa_item)
        if score > best_score:
            best_score = score
            best_match = qa_item

    # Determine response based on confidence
    if best_score >= 20:  # Lower threshold for better recall
        return {
            "answer": best_match['answer'],
            "confidence": best_score,
            "category": "matched"
        }
    else:
        return {
            "answer": DEFAULT_RESPONSE,
            "confidence": best_score,
            "category": "no_match"
        }


def get_suggestions(query):
    """
    Get suggested questions based on partial input
    """
    query = preprocess_text(query)
    suggestions = []

    for qa_item in COLLEGE_QA:
        for pattern in qa_item['patterns']:
            if any(word in pattern.lower() for word in query.split()):
                suggestion = pattern.capitalize()
                if not suggestion.endswith("?"):
                    suggestion += "?"
                if suggestion not in suggestions:
                    suggestions.append(suggestion)
                    break

        if len(suggestions) >= 5:
            break

    return suggestions


# Test function
if __name__ == "__main__":
    test_queries = [
        "Hello",
        "When are the exams?",
        "What is the fee structure?",
        "Tell me about hostel",
        "How to check results?",
        "What companies come for placement?",
        "Library timing please",
        "Where is the canteen?",
        "How to get bonafide certificate?",
        "What is Asli?",
        "Bus routes",
        "Thanks!",
        "xyz random query"
    ]

    print("=" * 60)
    print("ASLI CHATBOT - NLP TEST")
    print("=" * 60)

    for query in test_queries:
        response = get_chatbot_response(query)
        print(f"\n📝 Query: {query}")
        print(f"🎯 Confidence: {response['confidence']}%")
        print(f"📦 Category: {response['category']}")
        print(f"💬 Answer: {response['answer'][:80]}...")
        print("-" * 40)
