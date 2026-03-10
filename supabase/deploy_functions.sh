#!/usr/bin/env bash
# Deploy Edge Functions with JWT verification OFF at the gateway.
# The functions still validate the user JWT inside the handler (createClientFromReq + getAuthUser).
# This avoids 401 "Invalid JWT" when the gateway rejects ES256 tokens.
set -e
cd "$(dirname "$0")/.."
echo "Deploying create_reservation (--no-verify-jwt)..."
supabase functions deploy create_reservation --no-verify-jwt
echo "Deploying approve_reservation (--no-verify-jwt)..."
supabase functions deploy approve_reservation --no-verify-jwt
echo "Done."
