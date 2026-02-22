# CSI Hymns - Project Documentation

This document provides technical documentation for the CSI Hymns application, including setup instructions, configuration details, and service integrations.

---

## Services & Integrations

### 5. Jira

**Purpose:**
- Ticket creation for lyric issue reports
- Automated issue tracking from app feedback

**Configuration:**
Add the following variables to your `.env` file:

```
JIRA_URL=https://your-domain.atlassian.net
JIRA_EMAIL=your-email@example.com
JIRA_API_TOKEN=your-api-token
JIRA_PROJECT_KEY=HYMNS
JIRA_ISSUE_TYPE=Task
```

**Getting API Token:**
1. Go to https://id.atlassian.com/manage-profile/security/api-tokens
2. Click "Create API token"
3. Copy the token and add it to `.env` as `JIRA_API_TOKEN`

**Issue Type:**
- Default: `Task` (works with all Jira Cloud plans including Free)
- You can use either the issue type name (e.g., `Task`, `Bug`, `Story`) or the issue type ID (e.g., `10001`)
- To find available issue types:
  1. Go to your Jira project settings
  2. Navigate to Issue Types
  3. Check the available types or use Jira REST API: `GET /rest/api/3/issuetype`
- **Note:** "Task" is recommended as it's available on all plans and doesn't require premium features

**Features:**
- Automatic ticket creation from debug button
- Includes song metadata (type, number, title)
- Includes app version information
- Optional user description field
- In-app ticket tracking with status sync
- Email fallback if Jira is unavailable

**Fallback Behavior:**
- If Jira is not configured or fails, the app falls back to email
- Users can still report issues via email if Jira integration fails
- If Service Request issue type fails (premium feature), automatically falls back to "Task"

**Security Considerations:**
- Jira credentials are stored in `.env` file (not committed to git)
- API tokens should be kept secure
- Never commit `.env` file to version control

---

## 🗄 Database Schema

### Supabase Tables

#### `jira_tickets`
Stores Jira ticket information for tracking user-submitted issues.

```sql
CREATE TABLE jira_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_key TEXT NOT NULL UNIQUE,
    ticket_url TEXT NOT NULL,
    song_type TEXT NOT NULL,
    song_number INTEGER NOT NULL,
    song_title TEXT NOT NULL,
    description TEXT,
    app_version TEXT,
    jira_status TEXT DEFAULT 'Open',
    jira_status_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    device_id TEXT
);
```

---

*This documentation is updated as the project evolves.*
