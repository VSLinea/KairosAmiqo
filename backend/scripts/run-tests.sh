#!/usr/bin/env bash
set -euo pipefail

# 1) Ensure backend dev server is running (user starts it manually)
echo "⚠️  Make sure 'npm run dev' is running in another terminal on http://localhost:3000"

# 2) Get Firebase test token
echo "🔑 Fetching Firebase test token..."
TOKEN_LINE=$(node "$(dirname "$0")/get-test-jwt.js")
TOKEN=$(echo "$TOKEN_LINE" | sed 's/^TEST_FIREBASE_CUSTOM_TOKEN=//')

if [ -z "$TOKEN" ]; then
  echo "❌ Failed to obtain test token" >&2
  exit 1
fi

echo "✅ Got test token (truncated): ${TOKEN:0:16}..."

# 3) Run curl playlist
"$(dirname "$0")/api-tests.sh" "$TOKEN"
