# Edge Functions

**Note:** The Flutter app now creates reservations via **direct Supabase** (RPC + insert), so it no longer depends on the `create_reservation` Edge Function. You can keep or remove the function; the app will work without it.

## 401 "Invalid JWT" — fix (if you still use the Edge Function)

The gateway validates the JWT **before** the request reaches the function. If you see `{"code":401,"message":"Invalid JWT"}` (e.g. with ES256 user tokens), deploy with **JWT verification disabled at the gateway** (the function still checks the user inside):

```bash
# From project root
./supabase/deploy_functions.sh
# or manually:
supabase functions deploy create_reservation --no-verify-jwt
supabase functions deploy approve_reservation --no-verify-jwt
```

Redeploy after that and try again.

---

## create_reservation

Kailangan ng **user JWT** (yung token pagkatapos mag-login), hindi yung anon key o `sb_publishable_...`.

### 1. Kunin muna ang user token (Supabase Auth)

Sign-in muna, tapos kunin ang `access_token` sa response:

```bash
curl -L -X POST 'https://nyoogofpkqpdxnmeqsyv.supabase.co/auth/v1/token?grant_type=password' \
  -H 'apikey: YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  --data '{"email":"user@example.com","password":"yourpassword"}'
```

Sa response, copy ang `access_token` (mahaba, JWT na may `eyJ...`).

### 2. Tawagan ang create_reservation

Gamitin ang **anon key** sa `apikey` at ang **user access_token** sa `Authorization`:

```bash
curl -L -X POST 'https://nyoogofpkqpdxnmeqsyv.supabase.co/functions/v1/create_reservation' \
  -H 'Authorization: Bearer YOUR_USER_ACCESS_TOKEN' \
  -H 'apikey: YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  --data '{
    "court_id": "uuid-of-court",
    "date": "2025-03-15",
    "start_time": "10:00",
    "end_time": "11:00",
    "event_type": "basketball",
    "players_count": 10
  }'
```

Palitan:
- `YOUR_USER_ACCESS_TOKEN` = `access_token` mula sa sign-in (JWT, nagsisimula sa `eyJ...`)
- `YOUR_ANON_KEY` = project anon key sa Supabase Dashboard → Settings → API (JWT din)
- `court_id` = valid UUID ng court sa DB

### Bakit 401 kung mali ang token?

- **Authorization: Bearer sb_publishable_...** – hindi iyan user JWT; hindi makikilala ang user, kaya Unauthorized.
- Dapat **Bearer** + **access_token** mula sa **Supabase Auth** (pagkatapos mag-login).
