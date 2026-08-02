# Fomra LandIQ (fomra_ls)

Internal land-acquisition CRM for **Fomra Housing Pvt. Ltd.** — tracks land leads
from first contact through legal verification to a signed deal, with field
tools (GPS-verified site visits, offline mode, voice notes), management
oversight (multi-level approvals, monthly targets, audit trail), and a market
intelligence view that pulls in competitor listings and government land
records for a parcel's area.

Live app: https://fomra-ls.vercel.app

## Architecture at a glance

| Layer | Tech | Where |
|---|---|---|
| Client | Flutter (Web primary, + Android/iOS) | `lib/` |
| Data & Auth | Supabase (Postgres, Auth, Storage) | `supabase/*.sql` (schema + RLS, run manually in the Supabase SQL editor, in filename order) |
| Push notifications | Firebase Cloud Messaging | `lib/services/push_service.dart`, `api/push.js` |
| Serverless functions | Node.js on Vercel | `api/*.js` (thin wrappers around `backend/src/routes/*.js`) |

**Important:** the core CRM (leads, employees, approvals, notifications, audit
log) talks to Supabase **directly from the Flutter client** — there is no
custom backend for that data. `backend/` only contains the Market
Intelligence data-source integrations (99acres, MagicBricks, NoBroker,
Housing.com, TN RERA, TN land records, nearby-POI lookups) and is reachable
solely through the `api/*.js` Vercel functions. It is not a general-purpose
API server.

## Getting started

```bash
flutter pub get
flutter run -d chrome   # or an attached device/emulator
```

Supabase connection details live in `lib/services/supabase_config.dart`. The
serverless functions under `api/` need their own environment variables when
deployed to Vercel — see the comment block at the top of each file
(`api/employee-auth.js` and `api/push.js` document theirs in detail).

### Running tests

```bash
flutter test
```

## Repository layout

```
lib/
  screens/     UI, grouped by module (land_lead, legal, survey, broker, …)
  services/    Supabase calls, business logic, offline sync, auth
  models/      Data classes
  widgets/     Shared UI components
  theme/       App-wide styling
api/           Vercel serverless functions (market intel + admin auth + push)
backend/       Node code backing the market-intelligence api/ functions
supabase/      SQL: schema, RLS policies, migrations — apply manually via the
               Supabase SQL editor, in roughly chronological/filename order
test/          Flutter widget & unit tests
```

## Security model

Row-Level Security is enabled on every table. Application-level role checks
(admin / manager / executive) live in `lib/services/role_access.dart`, and are
backed by matching Postgres RLS policies — see `supabase/rls_lockdown.sql` and
`supabase/rls_lockdown_2_2026-08.sql` for what's actually enforced at the
database layer. **Do not run `supabase/rls_unlock.sql` against production** —
it exists only as a documented historical break-glass rollback; read its
header before touching it.

## Deployment

Vercel is the canonical deployment target (`vercel.json`). The build step
(`scripts/vercel-build.js`) downloads the Flutter SDK and compiles the web app
from source on every deploy.
