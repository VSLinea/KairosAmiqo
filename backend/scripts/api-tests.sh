#!/usr/bin/env bash
set -euo pipefail

TOKEN="$1"
BASE_URL="http://localhost:3000"

echo "[1] GET /health"
curl -sS "${BASE_URL}/health" | jq . || exit 1

echo "[2] GET /me"
curl -sS \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${BASE_URL}/me" | jq . || exit 1

echo "[3] POST /negotiate/start"
START_RESPONSE=$(curl -sS \
  -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${BASE_URL}/negotiate/start" \
  -d '{
    "negotiation_id": "'"$(uuidgen | tr '[:upper:]' '[:lower:]')"'",
    "intent_category": "dinner",
    "participant_count": 2,
    "expires_at": "2030-01-01T20:00:00Z",
    "proposed_slots": [
      {
        "starts_at": "2030-01-01T18:00:00Z",
        "duration_minutes": 90
      }
    ],
    "proposed_venues": [
      {
        "venue_name": "Test Restaurant",
        "venue_metadata": { "type": "restaurant" }
      }
    ],
    "encrypted_payload": "base64encodedencryptedpayload",
    "agent_mode": false
  }')

echo "$START_RESPONSE" | jq . || exit 1
NEGOTIATION_ID=$(echo "$START_RESPONSE" | jq -r '.data.id')
echo "Created negotiation: ${NEGOTIATION_ID}"

echo "[4] GET /negotiations/:id"
curl -sS \
  -H "Authorization: Bearer ${TOKEN}" \
  "${BASE_URL}/negotiations/${NEGOTIATION_ID}" | jq . || exit 1

echo "[5] GET /events/upcoming"
curl -sS \
  -H "Authorization: Bearer ${TOKEN}" \
  "${BASE_URL}/events/upcoming" | jq . || exit 1

echo "✅ API smoke tests completed."
