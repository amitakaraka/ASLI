# College Events Data
# Contains upcoming events, announcements, and important dates

from datetime import datetime, timedelta

def get_upcoming_events():
    """Get list of upcoming college events"""
    today = datetime.now()
    
    events = [
        {
            "id": 1,
            "title": "Tech Fest 2026",
            "description": "Annual technology festival with coding competitions, hackathons, and tech talks.",
            "date": (today + timedelta(days=15)).strftime("%Y-%m-%d"),
            "time": "9:00 AM",
            "venue": "Main Auditorium",
            "category": "fest",
            "image": "🎯"
        },
        {
            "id": 2,
            "title": "Mid-Semester Exams",
            "description": "Mid-semester examinations for all departments.",
            "date": (today + timedelta(days=20)).strftime("%Y-%m-%d"),
            "time": "10:00 AM",
            "venue": "Examination Halls",
            "category": "exam",
            "image": "📝"
        },
        {
            "id": 3,
            "title": "Cultural Night",
            "description": "Annual cultural program featuring music, dance, and drama performances.",
            "date": (today + timedelta(days=30)).strftime("%Y-%m-%d"),
            "time": "6:00 PM",
            "venue": "Open Air Theatre",
            "category": "cultural",
            "image": "🎭"
        },
        {
            "id": 4,
            "title": "Campus Placement Drive",
            "description": "Multiple companies visiting for recruitment. Prepare your resumes!",
            "date": (today + timedelta(days=25)).strftime("%Y-%m-%d"),
            "time": "9:00 AM",
            "venue": "Placement Cell",
            "category": "placement",
            "image": "💼"
        },
        {
            "id": 5,
            "title": "Sports Day",
            "description": "Annual sports meet with various athletic events and team competitions.",
            "date": (today + timedelta(days=45)).strftime("%Y-%m-%d"),
            "time": "7:00 AM",
            "venue": "Sports Ground",
            "category": "sports",
            "image": "🏆"
        },
        {
            "id": 6,
            "title": "Workshop: AI & Machine Learning",
            "description": "Hands-on workshop on AI/ML fundamentals by industry experts.",
            "date": (today + timedelta(days=10)).strftime("%Y-%m-%d"),
            "time": "2:00 PM",
            "venue": "Computer Lab 1",
            "category": "workshop",
            "image": "🤖"
        },
        {
            "id": 7,
            "title": "Fee Payment Deadline",
            "description": "Last date to pay semester fees without late fee penalty.",
            "date": (today + timedelta(days=7)).strftime("%Y-%m-%d"),
            "time": "5:00 PM",
            "venue": "Accounts Office / Online",
            "category": "deadline",
            "image": "💰"
        },
        {
            "id": 8,
            "title": "Alumni Meet",
            "description": "Annual gathering of alumni with networking opportunities.",
            "date": (today + timedelta(days=60)).strftime("%Y-%m-%d"),
            "time": "11:00 AM",
            "venue": "Conference Hall",
            "category": "networking",
            "image": "🤝"
        },
    ]
    
    # Sort by date
    events.sort(key=lambda x: x['date'])
    
    return events


def get_announcements():
    """Get important announcements"""
    return [
        {
            "id": 1,
            "title": "Library Extended Hours",
            "message": "Library will remain open until 10 PM during exam week.",
            "priority": "high",
            "date": datetime.now().strftime("%Y-%m-%d")
        },
        {
            "id": 2,
            "title": "New WiFi Password",
            "message": "Campus WiFi password has been updated. Check your email for details.",
            "priority": "medium",
            "date": datetime.now().strftime("%Y-%m-%d")
        },
        {
            "id": 3,
            "title": "Hostel Maintenance",
            "message": "Water supply will be interrupted on Sunday 8 AM - 12 PM for maintenance.",
            "priority": "low",
            "date": datetime.now().strftime("%Y-%m-%d")
        },
    ]
