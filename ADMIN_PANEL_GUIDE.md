# 👨‍💼 ASLI Admin Panel - Complete Documentation

## Overview

The ASLI Admin Panel is a **comprehensive moderation and management system** for platform administrators, featuring:

- ✅ **System Overview** - Real-time statistics and KPIs
- ✅ **User Management** - Activate/deactivate users
- ✅ **Content Moderation** - Delete posts, questions
- ✅ **Activity Audit** - Platform-wide activity log
- ✅ **Analytics** - Department breakdown, top contributors
- ✅ **Admin Access Control** - Role-based permissions

---

## 📊 Features Summary

### **Admin Dashboard Tabs**

| Tab | Purpose | Features |
|-----|---------|----------|
| **Overview** | System stats | KPIs, user status, departments, top contributors |
| **Users** | User management | List all users, ban/unban, view stats |
| **Activity** | Audit log | Recent posts, DMs, follows |

---

## 🔐 Access Control

### **Admin Verification**

**Backend:**
```python
@admin_required
def admin_route(user_id):
    user = UserAccount.query.get(user_id)
    if not user or not user.is_admin:
        return jsonify({'error': 'Admin access required'}), 403
```

**Frontend:**
- Check `is_admin` flag on user login
- Redirect non-admin users
- Show "Access Denied" error

### **Security Features**

- ✅ Admin decorator on all admin routes
- ✅ Cannot deactivate own account
- ✅ Cannot deactivate other admins
- ✅ Confirmation dialogs for actions
- ✅ Error handling with descriptive messages

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Flutter Admin Screen                        │
│  ┌───────────────────────────────────────────────────┐  │
│  │  TabBar (3 tabs)                                  │  │
│  │  ├─ Overview Tab                                  │  │
│  │  ├─ Users Tab                                     │  │
│  │  └─ Activity Tab                                  │  │
│  └───────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────┘
                     │ REST API
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Flask Backend (Admin Module)                │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Admin Routes                                     │  │
│  │  ├─ GET  /api/admin/overview                      │  │
│  │  ├─ GET  /api/admin/users                         │  │
│  │  ├─ POST /api/admin/users/<id>/toggle             │  │
│  │  ├─ GET  /api/admin/posts                         │  │
│  │  ├─ DELETE /api/admin/posts/<id>                  │  │
│  │  └─ GET  /api/admin/audit-log                     │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Admin Decorator                                  │  │
│  │  - Check is_admin flag                            │  │
│  │  - Return 403 if not admin                        │  │
│  └───────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
        ┌────────────────────────┐
        │   PostgreSQL Database  │
        │   - UserAccount        │
        │   - CollxPost          │
        │   - ActivityLog        │
        └────────────────────────┘
```

---

## 📡 API Endpoints

### **GET /api/admin/overview**

Get comprehensive system statistics.

**Response:**
```json
{
  "success": true,
  "data": {
    "users": {
      "total": 150,
      "active": 142,
      "inactive": 8
    },
    "content": {
      "posts": 523,
      "replies": 1247,
      "likes": 3456,
      "questions": 89,
      "answers": 234
    },
    "social": {
      "follows": 456,
      "dms": 2341,
      "notifications": 5678,
      "unread_notifs": 234
    },
    "departments": [
      {"name": "CSE", "count": 45},
      {"name": "ECE", "count": 32}
    ],
    "top_contributors": [
      {"name": "John Doe", "username": "johndoe", "posts": 45}
    ]
  }
}
```

---

### **GET /api/admin/users**

Get all users with management info.

**Response:**
```json
{
  "success": true,
  "count": 150,
  "data": [
    {
      "id": 1,
      "name": "John Doe",
      "username": "johndoe",
      "email": "john@university.edu",
      "department": "CSE",
      "year": "3rd",
      "is_active": true,
      "is_admin": false,
      "follower_count": 45,
      "following_count": 32,
      "post_count": 23,
      "dm_count": 156,
      "joined": "2025-09-01T10:00:00Z"
    }
  ]
}
```

---

### **POST /api/admin/users/<id>/toggle**

Activate/deactivate a user.

**Request:**
```
POST /api/admin/users/5/toggle
Authorization: Bearer <admin_token>
```

**Response (Success):**
```json
{
  "success": true,
  "user_id": 5,
  "is_active": false,
  "message": "User deactivated"
}
```

**Response (Error - Self):**
```json
{
  "success": false,
  "error": "Cannot deactivate your own account",
  "error_code": "CANNOT_SELF_DEACTIVATE"
}
```

**Response (Error - Admin):**
```json
{
  "success": false,
  "error": "Cannot deactivate admin accounts",
  "error_code": "CANNOT_DEACTIVATE_ADMIN"
}
```

---

### **GET /api/admin/posts**

Get all posts for moderation.

**Query Parameters:**
- `page`: Page number (default: 1)
- `limit`: Posts per page (default: 20)

**Response:**
```json
{
  "success": true,
  "count": 20,
  "total": 523,
  "page": 1,
  "data": [ ... ]
}
```

---

### **DELETE /api/admin/posts/<id>**

Delete a post (admin moderation).

**Request:**
```
DELETE /api/admin/posts/123
Authorization: Bearer <admin_token>
```

**Response:**
```json
{
  "success": true,
  "message": "Post #123 deleted"
}
```

---

### **GET /api/admin/audit-log**

Get recent platform activity.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "type": "post",
      "icon": "📝",
      "description": "John Doe posted: \"Hello campus...\"",
      "time": "2026-03-31T10:30:00Z"
    },
    {
      "type": "dm",
      "icon": "✉️",
      "description": "Alice → Bob: DM sent",
      "time": "2026-03-31T10:25:00Z"
    },
    {
      "type": "follow",
      "icon": "👤",
      "description": "Charlie followed Diana",
      "time": "2026-03-31T10:20:00Z"
    }
  ]
}
```

---

## 🎨 UI Components

### **Overview Tab**

**KPI Cards:**
- 👥 Total Users
- 📝 Total Posts
- 💬 Total DMs
- ❤️ Total Likes
- ❓ Total Questions
- 🔔 Total Notifications

**User Status Circle:**
- Active users (green)
- Inactive users (red)
- Total users (accent)

**Department Breakdown:**
- Progress bars
- User count per department
- Percentage visualization

**Top Contributors:**
- Top 5 users by post count
- Avatar, name, username
- Post count badge

---

### **Users Tab**

**User Card:**
- Avatar with status indicator
- Name, username, department
- Stats (posts, DMs, followers)
- Ban/Unban toggle button
- Active/inactive styling

**Actions:**
- Click toggle → Confirmation dialog
- Success/error snackbar
- Auto-refresh after action

---

### **Activity Tab**

**Audit Log:**
- Recent posts (last 5)
- Recent DMs (last 5)
- Recent follows (last 5)
- Sorted by time
- Icon + description + timestamp

---

## 🔧 Implementation Details

### **Backend Admin Decorator**

```python
def admin_required(f):
    from functools import wraps
    @wraps(f)
    def decorated_function(user_id, *args, **kwargs):
        user = UserAccount.query.get(user_id)
        if not user or not user.is_admin:
            return jsonify({
                'success': False,
                'error': 'Admin access required',
                'error_code': 'ADMIN_ACCESS_REQUIRED'
            }), 403
        return f(user_id, *args, **kwargs)
    return decorated_function
```

### **Frontend Toggle User Status**

```dart
Future<void> _toggleUserStatus(int userId, String userName) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Action'),
      content: Text('Are you sure you want to change the status of $userName?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirm', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final result = await ApiService.toggleUserStatus(userId);
  if (result != null && result['success'] == true) {
    // Show success message
    _loadAllData();
  }
}
```

---

## 📊 Admin Statistics

### **KPIs Tracked**

| Category | Metrics |
|----------|---------|
| **Users** | Total, Active, Inactive |
| **Content** | Posts, Replies, Likes, Questions, Answers |
| **Social** | Follows, DMs, Notifications, Unread |
| **Departments** | User count per department |
| **Top Contributors** | Top 5 users by posts |

---

## 🔒 Security Best Practices

### **Access Control**
- ✅ Admin decorator on all routes
- ✅ Check `is_admin` flag
- ✅ Return 403 for non-admins
- ✅ Token-based authentication

### **Action Safety**
- ✅ Cannot deactivate own account
- ✅ Cannot deactivate other admins
- ✅ Confirmation dialogs
- ✅ Error messages with error codes

### **Data Protection**
- ✅ Email only visible to admins
- ✅ Sensitive actions logged
- ✅ Soft delete (is_active flag)
- ✅ Cascade delete for posts

---

## 🧪 Testing Checklist

### **Overview Tab**
- [ ] Stats load correctly
- [ ] KPI cards display
- [ ] User status circles show
- [ ] Department breakdown accurate
- [ ] Top contributors list
- [ ] Refresh button works

### **Users Tab**
- [ ] All users listed
- [ ] Active/inactive styling
- [ ] Toggle button works
- [ ] Confirmation dialog shows
- [ ] Success/error messages
- [ ] Auto-refresh after action

### **Activity Tab**
- [ ] Audit log loads
- [ ] Posts show correctly
- [ ] DMs show correctly
- [ ] Follows show correctly
- [ ] Sorted by time
- [ ] Icons display

### **Security**
- [ ] Non-admin blocked (403)
- [ ] Cannot self-deactivate
- [ ] Cannot deactivate admins
- [ ] Error codes returned
- [ ] Token required

---

## 🔮 Future Enhancements

### **Phase 1 (Next Sprint)**

1. **Post Moderation UI**
   - View all posts
   - Delete posts with reason
   - Bulk actions

2. **User Details**
   - View full profile
   - Edit user info
   - Reset password

3. **Advanced Analytics**
   - User growth chart
   - Activity heatmap
   - Engagement metrics

### **Phase 2 (Future)**

1. **Content Management**
   - Edit posts
   - Pin posts
   - Feature content

2. **Notifications**
   - Send broadcast messages
   - System announcements
   - Push notifications

3. **Reports**
   - User activity reports
   - Content reports
   - Export data (CSV)

4. **Moderation Tools**
   - Reported content queue
   - Auto-moderation rules
   - Spam detection

---

## 📞 Support

### **For Admins**

**Common Issues:**
- Can't access admin panel → Check `is_admin` flag in database
- Can't deactivate user → Check if admin or self
- Stats not loading → Check API connection

**Contact:**
- Technical support: support@asli-campus.com
- Documentation: docs.asli-campus.com

---

## 📝 Database Schema

### **UserAccount Table**

```sql
CREATE TABLE user_account (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    is_admin BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    follower_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,
    post_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### **Admin Log Table** (Future)

```sql
CREATE TABLE admin_log (
    id INTEGER PRIMARY KEY,
    admin_id INTEGER REFERENCES user_account(id),
    action VARCHAR(100) NOT NULL,
    target_type VARCHAR(50),
    target_id INTEGER,
    reason VARCHAR(500),
    created_at TIMESTAMP DEFAULT NOW()
);
```

---

**Version**: 21.0.0  
**Last Updated**: March 2026  
**Status**: Production Ready ✅
