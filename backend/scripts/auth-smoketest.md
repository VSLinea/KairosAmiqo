# Backend Auth Smoke Test

## Purpose
Quick manual verification that backend authentication endpoints are working correctly.

## Prerequisites
- Backend server running: `npm run dev` from `/backend`
- Valid Firebase test user (e.g., `user_1@test.com`)
- Terminal with `curl` and `jq` installed

## Test Cases

### 1. Health Check (No Auth Required)
```bash
curl -s http://127.0.0.1:3000/health | jq .
```

**Expected:**
```json
{
  "data": {
    "status": "ok",
    "uptime_seconds": 123,
    "timestamp": "2025-11-23T..."
  },
  "meta": {
    "request_id": "...",
    "timestamp": "2025-11-23T..."
  }
}
```

---

### 2. Auth Debug Without Token (Should Fail)
```bash
curl -s http://127.0.0.1:3000/auth/debug | jq .
```

**Expected:**
```json
{
  "error": {
    "code": "unauthorized",
    "message": "Missing Authorization header"
  }
}
```

**Status Code:** `401`

---

### 3. Auth Verify With Invalid Token (Should Fail)
```bash
curl -s http://127.0.0.1:3000/auth/verify \
  -H "Authorization: Bearer invalid_token_12345" | jq .
```

**Expected:**
```json
{
  "error": {
    "code": "invalid_token",
    "message": "Firebase token validation failed"
  }
}
```

**Status Code:** `401`

---

### 4. Get Valid Token (Test User)
```bash
# From backend directory
cd /Users/lyra/KairosMain/KairosAmiqo/backend
node scripts/get-test-jwt.js --email user_1@test.com
```

**Copy the `idToken` value for next steps**

---

### 5. Auth Debug With Valid Token (Should Succeed)
```bash
# Replace <VALID_TOKEN> with actual token from step 4
curl -s http://127.0.0.1:3000/auth/debug \
  -H "Authorization: Bearer <VALID_TOKEN>" | jq .
```

**Expected:**
```json
{
  "data": {
    "userId": "...",
    "email": "user_1@test.com",
    "displayName": null,
    "authenticated": true
  },
  "meta": {
    "requestId": "...",
    "timestamp": "2025-11-23T..."
  }
}
```

**Status Code:** `200`

---

### 6. Auth Verify With Valid Token (Should Succeed)
```bash
# Replace <VALID_TOKEN> with actual token from step 4
curl -s http://127.0.0.1:3000/auth/verify \
  -H "Authorization: Bearer <VALID_TOKEN>" | jq .
```

**Expected:**
```json
{
  "data": {
    "status": "ok",
    "authenticated": true,
    "userId": "..."
  },
  "meta": {
    "requestId": "...",
    "timestamp": "2025-11-23T..."
  }
}
```

**Status Code:** `200`

---

### 7. /me Endpoint With Valid Token
```bash
# Replace <VALID_TOKEN> with actual token from step 4
curl -s http://127.0.0.1:3000/me \
  -H "Authorization: Bearer <VALID_TOKEN>" | jq .
```

**Expected:**
```json
{
  "data": {
    "id": "...",
    "firebase_uid": "...",
    "email": "user_1@test.com",
    "created_at": "...",
    "updated_at": "..."
  },
  "meta": {
    "timestamp": "..."
  }
}
```

**Status Code:** `200`

---

## Quick One-Liner Test (Valid Token)

After getting a valid token, test all protected endpoints:

```bash
TOKEN="<VALID_TOKEN_HERE>"

echo "=== Testing /auth/debug ===" && \
curl -s http://127.0.0.1:3000/auth/debug -H "Authorization: Bearer $TOKEN" | jq . && \
echo "" && \
echo "=== Testing /auth/verify ===" && \
curl -s http://127.0.0.1:3000/auth/verify -H "Authorization: Bearer $TOKEN" | jq . && \
echo "" && \
echo "=== Testing /me ===" && \
curl -s http://127.0.0.1:3000/me -H "Authorization: Bearer $TOKEN" | jq .
```

---

## Troubleshooting

### Error: "Connection refused"
- Backend not running
- Wrong port (should be 3000)
- **Fix:** Run `npm run dev` from `/backend`

### Error: "expired_token"
- Token is older than 1 hour
- **Fix:** Generate new token with `get-test-jwt.js`

### Error: "invalid_token"
- Malformed token
- Wrong Firebase project
- **Fix:** Verify `firebase-admin.json` is correct

### Multiple servers running
```bash
# Check what's on port 3000
lsof -ti:3000

# Kill old processes
kill $(lsof -ti:3000)

# Start fresh
npm run dev
```

---

## Known Edge Cases

1. **Development Mode Token Fallback**
   - In dev mode, backend may decode tokens without full verification
   - Check logs for: "Using unverified custom token in development mode"

2. **Request ID Tracking**
   - Every response includes `meta.requestId`
   - Use this to correlate logs with requests

3. **Structured Auth Logging**
   - Auth failures log: `{ reason: 'expired|invalid|revoked', requestId, path }`
   - No sensitive data (tokens) in logs
