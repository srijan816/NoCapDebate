# Analytics Testing Guide

## Quick Start: Test Current Implementation

### 1. Backend Setup (5 minutes)

```bash
# Navigate to backend directory
cd feedback-backend

# Run the analytics migration
psql -d debate_feedback -U postgres -f database/migrations/005_create_analytics_tables.sql

# Verify tables created
psql -d debate_feedback -U postgres -c "\dt analytics*"
# Should show: analytics_events, user_sessions, daily_user_metrics, feature_usage, error_logs, performance_metrics

# Start the backend server (if not already running)
npm run dev
```

### 2. iOS App Setup (2 minutes)

```bash
# Navigate to iOS directory
cd DebateFeedback

# Open in Xcode
open DebateFeedback.xcodeproj

# Build and run in simulator (⌘R)
```

### 3. Test Analytics Flow (5 minutes)

**Step 1: App Launch**
- Launch the app in simulator
- Check Xcode console for:
  ```
  ✅ Analytics Service configured with 2 provider(s)
  📊 Event: app_opened
  ```

**Step 2: Login**
- Enter a teacher name (e.g., "Test Teacher")
- Click login
- Check console for:
  ```
  📊 Event: auth_login_initiated
  📊 Event: auth_login_success | Params: [is_returning_user: false, auth_method: teacher]
  👤 User Property: user_type = teacher
  🆔 User ID: {hashed_id}
  ```

**Step 3: Guest Mode (Alternative)**
- Click "Continue as Guest"
- Check console for:
  ```
  📊 Event: auth_guest_mode_selected
  👤 User Property: user_type = guest
  ```

**Step 4: Verify Backend Received Events**
```bash
# Check if events were sent to backend
psql -d debate_feedback -U postgres -c "
  SELECT event_name, user_type, device_id, client_timestamp
  FROM analytics_events
  ORDER BY server_timestamp DESC
  LIMIT 10;
"
```

Expected output:
```
     event_name      | user_type | device_id | client_timestamp
---------------------+-----------+-----------+------------------
 auth_login_success  | teacher   | xxx-xxx   | 2026-01-05...
 auth_login_initiated| teacher   | xxx-xxx   | 2026-01-05...
 app_opened          | guest     | xxx-xxx   | 2026-01-05...
```

**Step 5: Check Aggregated Data**
```bash
# Check user sessions
psql -d debate_feedback -U postgres -c "
  SELECT session_id, user_type, num_events, session_start
  FROM user_sessions
  ORDER BY session_start DESC
  LIMIT 5;
"

# Check daily metrics
psql -d debate_feedback -U postgres -c "
  SELECT metric_date, events_count, debates_created
  FROM daily_user_metrics
  WHERE metric_date = CURRENT_DATE;
"
```

---

## Testing Checklist

### ✅ Backend Verification

- [ ] All tables created successfully
  ```bash
  psql -d debate_feedback -c "\dt analytics*"
  ```

- [ ] All indexes created
  ```bash
  psql -d debate_feedback -c "\di analytics*"
  ```

- [ ] Materialized views created
  ```bash
  psql -d debate_feedback -c "\dm"
  # Should show: user_retention_cohorts, feature_adoption_stats, daily_active_users_summary
  ```

- [ ] Triggers created
  ```bash
  psql -d debate_feedback -c "
    SELECT trigger_name, event_manipulation, event_object_table
    FROM information_schema.triggers
    WHERE trigger_schema = 'public';
  "
  # Should show: trg_update_session_metrics, trg_update_daily_user_metrics
  ```

- [ ] Analytics routes registered
  ```bash
  # Check server logs on startup
  grep "Analytics" logs/app.log
  ```

### ✅ iOS Verification

- [ ] Analytics service configured on launch
  - Console shows: "✅ Analytics Service configured"

- [ ] Debug analytics provider active in DEBUG mode
  - Console shows analytics events with 📊 emoji

- [ ] Backend analytics provider active
  - Console shows: "✅ Analytics: Sent X events successfully"

- [ ] Authentication events logged
  - `app_opened`
  - `auth_login_initiated`
  - `auth_login_success` or `auth_guest_mode_selected`

- [ ] User properties set
  - `user_type` (teacher/guest)
  - `device_id`

- [ ] User ID hashed
  - Console shows hashed ID, NOT plain teacher name

### ✅ Backend API Testing

**Test 1: Log Events (Unauthenticated)**
```bash
curl -X POST http://localhost:3000/api/analytics/events \
  -H "Content-Type: application/json" \
  -d '{
    "events": [
      {
        "event_name": "test_event",
        "session_id": "test-session-123",
        "device_id": "test-device-456",
        "user_type": "teacher",
        "client_timestamp": "2026-01-05T12:00:00Z",
        "properties": {
          "test_property": "test_value",
          "test_number": 42
        }
      }
    ]
  }'
```

Expected response:
```json
{
  "success": true,
  "events_logged": 1
}
```

**Test 2: Get Teacher Analytics (Authenticated)**
```bash
# First, login to get a token
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "teacher_id": "Test Teacher",
    "device_id": "test-device-123"
  }'

# Copy the token from response, then:
curl http://localhost:3000/api/analytics/teacher/{teacher_id} \
  -H "Authorization: Bearer {token}"
```

Expected response:
```json
{
  "overview": {
    "teacher_id": "...",
    "teacher_name": "Test Teacher",
    "total_sessions": 2,
    "total_debates": 0,
    "total_recordings": 0,
    "recent_sessions": 2,
    "avg_session_duration_seconds": 120,
    "playable_moments_engagement_rate": 0,
    "features_used": [],
    "upload_success_rate": 0,
    "error_rate": 0,
    "days_active": 1
  }
}
```

**Test 3: Error Logging**
```bash
curl -X POST http://localhost:3000/api/analytics/errors \
  -H "Content-Type: application/json" \
  -d '{
    "errors": [
      {
        "device_id": "test-device",
        "error_type": "test_error",
        "error_message": "This is a test error",
        "screen_name": "TestView",
        "client_timestamp": "2026-01-05T12:00:00Z"
      }
    ]
  }'
```

**Test 4: Admin Endpoints (Requires Admin Token)**
```bash
# DAU Summary
curl http://localhost:3000/api/analytics/dau?days=7 \
  -H "Authorization: Bearer {admin_token}"

# Retention Cohorts
curl http://localhost:3000/api/analytics/retention \
  -H "Authorization: Bearer {admin_token}"

# Feature Adoption
curl http://localhost:3000/api/analytics/features \
  -H "Authorization: Bearer {admin_token}"
```

---

## Common Issues & Troubleshooting

### Issue 1: "Analytics: Invalid URL"
**Symptom:** iOS console shows "❌ Analytics: Invalid URL"

**Solution:**
- Check `Constants.API.baseURL` in iOS app
- Verify backend is running on correct port
- For simulator, use `http://localhost:3000` NOT `http://127.0.0.1:3000`

### Issue 2: "Analytics: Server returned status 404"
**Symptom:** Events not reaching backend, 404 errors

**Solution:**
- Verify analytics routes registered in `server.ts`
- Check if `import analyticsRoutes from './routes/analytics.js'` exists
- Restart backend server

### Issue 3: No events in database
**Symptom:** iOS shows success but database is empty

**Solution:**
- Check backend logs for errors:
  ```bash
  tail -f logs/app.log | grep -i analytics
  ```
- Verify database connection is working
- Check if triggers are enabled:
  ```sql
  SELECT * FROM pg_trigger WHERE tgname LIKE '%analytics%';
  ```

### Issue 4: Events not batching
**Symptom:** Every event sends immediately instead of batching

**Solution:**
- This is expected for first 10 events
- Wait 30 seconds for periodic flush
- Or trigger flush by backgrounding the app (Home button in simulator)

### Issue 5: TypeScript compilation errors
**Symptom:** Backend won't start due to TypeScript errors

**Solution:**
- Check if all type definitions are imported:
  ```bash
  cd feedback-backend
  npm install
  npm run build
  ```
- Verify `src/types/analytics.ts` exists

---

## Database Queries for Debugging

### View All Recent Events
```sql
SELECT
  event_name,
  user_type,
  properties,
  client_timestamp,
  server_timestamp
FROM analytics_events
ORDER BY server_timestamp DESC
LIMIT 20;
```

### Count Events by Type
```sql
SELECT
  event_name,
  COUNT(*) as count
FROM analytics_events
GROUP BY event_name
ORDER BY count DESC;
```

### View User Sessions
```sql
SELECT
  session_id,
  user_type,
  session_start,
  session_end,
  num_events,
  EXTRACT(EPOCH FROM (session_end - session_start)) as duration_seconds
FROM user_sessions
ORDER BY session_start DESC
LIMIT 10;
```

### View Daily Metrics
```sql
SELECT
  metric_date,
  SUM(events_count) as total_events,
  SUM(debates_created) as total_debates,
  COUNT(DISTINCT user_id) as unique_users
FROM daily_user_metrics
GROUP BY metric_date
ORDER BY metric_date DESC
LIMIT 7;
```

### View Error Logs
```sql
SELECT
  error_type,
  error_message,
  screen_name,
  user_action,
  COUNT(*) as occurrences
FROM error_logs
GROUP BY error_type, error_message, screen_name, user_action
ORDER BY occurrences DESC;
```

### Check Materialized View Data
```sql
-- Retention cohorts
SELECT * FROM user_retention_cohorts
ORDER BY cohort_week DESC;

-- Feature adoption
SELECT * FROM feature_adoption_stats
ORDER BY total_users DESC;

-- DAU summary
SELECT * FROM daily_active_users_summary
ORDER BY metric_date DESC
LIMIT 7;
```

---

## Performance Testing

### Test Event Batching
```swift
// In iOS app, add to DebateFeedbackApp.swift setupApp():
#if DEBUG
for i in 1...15 {
    AnalyticsService.shared.logEvent("test_batch_event_\(i)")
}
#endif
```

Expected:
- First 10 events trigger immediate flush
- Next 5 events wait for 30-second timer
- Console shows: "✅ Analytics: Sent 10 events successfully"
- Then after 30s: "✅ Analytics: Sent 5 events successfully"

### Test Background Flush
1. Launch app
2. Perform 3-4 actions (login, navigate)
3. Press Home button (Cmd+Shift+H in simulator)
4. Check console for: "✅ Analytics: Sent X events successfully"

### Test Retry Logic
1. Stop backend server
2. Perform actions in iOS app
3. Console shows: "❌ Analytics: Error sending events"
4. Events queued in memory
5. Restart backend server
6. Events auto-retry on next flush (30s timer)

---

## Next Testing Phase

Once remaining integrations are complete (setup, recording, feedback, history), test:

1. **Complete User Flow**
   - Login → Setup → Record → View Feedback → History
   - Verify all events logged at each step

2. **Funnel Analysis**
   ```sql
   SELECT
     COUNT(DISTINCT CASE WHEN event_name = 'setup_started' THEN session_id END) as setup_started,
     COUNT(DISTINCT CASE WHEN event_name = 'setup_completed' THEN session_id END) as setup_completed,
     COUNT(DISTINCT CASE WHEN event_name = 'recording_started' THEN session_id END) as recording_started,
     COUNT(DISTINCT CASE WHEN event_name = 'recording_session_completed' THEN session_id END) as recording_completed,
     COUNT(DISTINCT CASE WHEN event_name = 'feedback_detail_viewed' THEN session_id END) as feedback_viewed,
     COUNT(DISTINCT CASE WHEN event_name = 'playable_moment_clicked' THEN session_id END) as playable_clicked
   FROM analytics_events;
   ```

3. **Performance Validation**
   - App feels responsive (no lag from analytics)
   - Network usage reasonable (<1MB per 100 events)
   - Battery impact minimal

---

## Monitoring in Production

### Daily Health Check
```sql
-- Events logged today
SELECT COUNT(*) FROM analytics_events
WHERE server_timestamp::date = CURRENT_DATE;

-- Unique users today
SELECT COUNT(DISTINCT user_id) FROM analytics_events
WHERE server_timestamp::date = CURRENT_DATE;

-- Error rate
SELECT
  COUNT(*) FILTER (WHERE event_name = 'error_occurred')::float / COUNT(*)::float * 100 as error_percentage
FROM analytics_events
WHERE server_timestamp >= NOW() - INTERVAL '24 hours';
```

### Weekly Analysis
```sql
-- Run materialized view refresh
SELECT refresh_analytics_views();

-- Check retention
SELECT * FROM user_retention_cohorts
WHERE cohort_week >= CURRENT_DATE - INTERVAL '4 weeks'
ORDER BY cohort_week DESC;

-- Top events
SELECT event_name, COUNT(*) as count
FROM analytics_events
WHERE server_timestamp >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY event_name
ORDER BY count DESC
LIMIT 20;
```

---

**Happy Testing! 🧪**

If you encounter issues not covered here, check the backend logs and iOS console for detailed error messages.
