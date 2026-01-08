#!/bin/bash

# Generates Apple Client Secret for Supabase Auth (Sign in with Apple)
# Usage: ./tool/generate_secret.sh [P8_PATH]

# Load variables from .env if present
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Configuration - Prefer .env, fallback to arguments or empty
P8_FILE="${1:-$APPLE_AUTH_KEY_PATH}"
TEAM_ID="${APPLE_TEAM_ID}"
KEY_ID="${APPLE_KEY_ID}"
CLIENT_ID="${APPLE_CLIENT_ID:-com.kurabe.app.service}" 
DAYS=180

# Validate inputs
if [ -z "$P8_FILE" ] || [ -z "$TEAM_ID" ] || [ -z "$KEY_ID" ]; then
    echo "Error: Missing configuration."
    echo "Please ensure P8_FILE (arg), APPLE_TEAM_ID (.env), and APPLE_KEY_ID (.env) are set."
    echo "Usage: ./tool/generate_secret.sh ./AuthKey_XXXX.p8"
    exit 1
fi

if [ ! -f "$P8_FILE" ]; then
    echo "Error: Private key file '$P8_FILE' not found."
    exit 1
fi

echo "Generating Client Secret..."
echo "Team ID: $TEAM_ID"
echo "Key ID: $KEY_ID"
echo "Service ID: $CLIENT_ID"

node tool/generate_apple_client_secret.mjs \
  --p8 "$P8_FILE" \
  --team-id "$TEAM_ID" \
  --key-id "$KEY_ID" \
  --client-id "$CLIENT_ID" \
  --days "$DAYS"

echo ""
echo "Done! Copy the token above to Supabase Dashboard > Auth > Providers > Apple > Secret Key"
