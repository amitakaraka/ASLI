# =========================
#  ANDHRA UNIVERSITY — Official Knowledge Base for ASLI Chatbot
#  Sources:
#    - https://www.andhrauniversity.edu.in/
#    - https://www.linkedin.com/school/andhra-university/
#  Last Updated: March 2026 (Centenary Year)
# =========================

# Import complete knowledge base from the comprehensive module
from knowledge_base_complete import COLLEGE_QA

# Greeting patterns
GREETINGS = {
    "keywords": ["hello", "hi", "hey", "good morning", "good afternoon", "good evening",
                 "namaste", "hii", "helo", "sup", "yo", "namaskar", "namaskaram"],
    "answer": "\ud83d\udc4b **Hey there! Welcome to Asli!**\n\n"
              "I'm your Andhra University campus assistant \u2014 powered by data from "
              "AU's official website & LinkedIn (257K+ followers)!\n\n"
              "I can help with admissions, exams, fees, hostels, placements, certificates & more!\n\n"
              "Just type your question or tap a quick topic. \ud83d\ude0a"
}

# Thank you response
THANKS = {
    "keywords": ["thank", "thanks", "thank you", "thankyou", "tq", "thx", "ty", "dhanyavaad"],
    "answer": "\ud83d\ude0a **You're welcome!** Happy to help.\n\n"
              "Feel free to ask anything else about Andhra University \u2014 I'm always here! \ud83c\udf93\n\n"
              "Jai Hind! \ud83c\uddee\ud83c\uddf3"
}

# Default response when no match is found
DEFAULT_RESPONSE = (
    "\ud83e\udd14 I'm not sure about that. Here's what I can help with:\n\n"
    "\u2022 \ud83c\udfdb\ufe0f About AU & Rankings\n"
    "\u2022 \ud83d\udccb Admissions & Courses\n"
    "\u2022 \ud83d\udcc5 Exams & Results\n"
    "\u2022 \ud83d\udcb0 Fees & Scholarships\n"
    "\u2022 \ud83d\udcd6 Library & MOOCs\n"
    "\u2022 \ud83c\udfe0 Hostel & Campus\n"
    "\u2022 \ud83d\udcbc Placements & Research\n"
    "\u2022 \ud83d\udcdc Certificates & Transcripts\n"
    "\u2022 \ud83d\udcde Contact Info & Grievances\n"
    "\u2022 \ud83c\udf89 Centenary Celebrations\n"
    "\u2022 \ud83d\ude80 Innovation & Startups\n"
    "\u2022 \ud83d\udcf1 Social Media & LinkedIn\n\n"
    "Try rephrasing, or visit: www.andhrauniversity.edu.in"
)
