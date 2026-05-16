# DEPLOYMENT.md — Self-Hosted VPS Setup & Database Connection

> The system must run on **the tenant's own VPS**, not on Anthropic's cloud Supabase.
> This protects each tenant's data sovereignty (their data stays on their server).

---

## 1. The Deployment Model

There are **two deployment modes**:

### 1.1 Mode A: Self-Hosted (Recommended for Each Tenant)
Each company (tenant) has their **own server** running their **own Supabase instance**. The Flutter app connects to their server. No data ever leaves their infrastructure.

```
┌──────────────────────────────────────────────┐
│  COMPANY A — Hayat Secret (Kuwait)           │
│  ──────────────────────────────────────────  │
│  VPS in Kuwait (Hetzner/Contabo/DigitalOcean)│
│    ├── Supabase (self-hosted via Docker)     │
│    │     - PostgreSQL                         │
│    │     - GoTrue (auth)                      │
│    │     - PostgREST                          │
│    │     - Realtime                           │
│    │     - Storage                            │
│    │     - Edge Runtime                       │
│    ├── Nginx (reverse proxy + SSL)            │
│    └── Backups to S3-compatible storage       │
│                                                │
│  Flutter app connects to:                     │
│    https://api.hayatsecret.com                │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│  COMPANY B — Different Company (Saudi)        │
│  ──────────────────────────────────────────  │
│  Their own VPS in Saudi (separate)            │
│    ├── Supabase (same Docker stack)           │
│    ├── Nginx                                  │
│    └── Their own backups                      │
│                                                │
│  Flutter app connects to:                     │
│    https://api.companyB.com                   │
└──────────────────────────────────────────────┘
```

**Multi-tenant within one VPS:** Even though each company runs their own server, the system is **still multi-tenant inside that server**. This means:
- One company can have multiple branches/divisions as sub-tenants
- Future-ready: if a company wants to offer it to franchisees, they can

### 1.2 Mode B: SaaS-Hosted (Optional, Future)
The system creator (you) runs a central VPS hosting multiple smaller customers. They pay a monthly fee. They share the database (tenant_id isolation). This is the typical SaaS model.

**For v1: focus on Mode A only.** SaaS hosting is Phase 13+.

---

## 2. VPS Recommendations

### 2.1 Minimum Specs (Single Tenant, ~150 active contracts)
- **2 vCPU**
- **4 GB RAM**
- **40 GB SSD** (Postgres + Storage)
- **Bandwidth:** 2 TB/month (mobile photo uploads consume bandwidth)
- **Location:** geographically close to the team (Kuwait → Frankfurt/Bahrain region)

### 2.2 Recommended Specs (Production, Comfortable Headroom)
- **4 vCPU**
- **8 GB RAM**
- **100 GB SSD**
- **Bandwidth:** 5 TB/month

### 2.3 VPS Providers (Reasonable Prices)

| Provider | Approx Monthly | Notes |
|----------|---------------|-------|
| Hetzner (Germany) | €10–€20 | Excellent value, EU data centers |
| Contabo | $8–$15 | Cheapest, decent reliability |
| DigitalOcean | $24–$48 | Premium support, $200 credit promo often available |
| Vultr | $20–$40 | Good Asia/ME locations |
| Linode (Akamai) | $20–$40 | Solid performance |

For Kuwait, latency is best from **Bahrain (AWS me-south-1)** or **Frankfurt**.

---

## 3. The Supabase Self-Hosting Stack

Supabase is fully open-source and runs via Docker Compose. Official docker repo: `supabase/docker`.

### 3.1 What Gets Installed

```
docker-compose.yml runs these containers:

  studio          → Admin UI (https://studio.yourdomain.com)
  kong            → API gateway
  auth (gotrue)   → User authentication
  rest (postgrest)→ Auto-generated REST API
  realtime        → WebSocket pubsub
  storage         → File storage (S3-compatible)
  imgproxy        → Image transformations
  meta            → DB metadata
  functions       → Edge Functions runtime (Deno)
  analytics       → Logs
  db (postgres)   → The database itself
  vector          → Log shipping
  supavisor       → Connection pooler
```

### 3.2 Setup Steps (Summary)

```bash
# On the VPS:
1. Install Docker + Docker Compose
2. git clone --depth 1 https://github.com/supabase/supabase
3. cd supabase/docker
4. cp .env.example .env
5. Edit .env with strong secrets:
   - POSTGRES_PASSWORD (32+ chars)
   - JWT_SECRET (32+ chars)
   - ANON_KEY (generated from JWT_SECRET)
   - SERVICE_ROLE_KEY (generated from JWT_SECRET)
   - SITE_URL (https://app.yourdomain.com)
   - SMTP credentials (Resend, Sendgrid, etc.)
6. docker compose up -d
7. Configure Nginx reverse proxy with Let's Encrypt SSL
8. Open ports 80, 443 only (NOT direct postgres port)
9. Run migrations (from supabase/migrations/) via Studio or CLI
10. Create initial tenant via SQL or admin script
```

### 3.3 Domain & SSL Setup

The tenant points two subdomains at the VPS:
- `api.theirdomain.com` → Kong gateway (port 8000 internally)
- `studio.theirdomain.com` → Supabase Studio admin UI (port 3000 internally) — **restricted by IP whitelist or VPN**

Nginx config (simplified):

```nginx
server {
  listen 443 ssl http2;
  server_name api.theirdomain.com;
  ssl_certificate     /etc/letsencrypt/live/.../fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/.../privkey.pem;

  client_max_body_size 50M;   # for photo uploads

  location / {
    proxy_pass http://localhost:8000;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # WebSocket support for realtime
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}
```

### 3.4 Backups (Critical)

Two-layer backup strategy:

**A. Daily PostgreSQL dumps (on-server retention):**
```bash
# Cron: 02:00 daily
docker exec supabase-db pg_dump -U postgres postgres \
  | gzip > /var/backups/db_$(date +%Y%m%d).sql.gz

# Keep last 7 days locally
find /var/backups -name "db_*.sql.gz" -mtime +7 -delete
```

**B. Weekly off-site backups to S3-compatible storage:**
```bash
# Cron: Sundays 03:00
aws s3 sync /var/backups/ s3://bucket-name/ --endpoint-url ...
```

Recommended off-site providers: Wasabi ($6/TB/month), Backblaze B2 ($6/TB/month), Cloudflare R2 (no egress fees).

**C. Storage bucket backup:**
Photos and PDFs in Supabase Storage are stored in `/var/lib/docker/volumes/supabase_storage`. Include this directory in the off-site sync.

### 3.5 Monitoring

- **Uptime:** UptimeRobot or Better Stack (free tier sufficient)
- **Server health:** Netdata installed on VPS (free, real-time CPU/RAM/disk)
- **Database:** Supabase Studio's built-in performance panel
- **App errors:** Sentry (free tier 5k events/month)
- **Daily email digest:** custom Edge Function summarizing the day's activity

---

## 4. How the Flutter App Connects

### 4.1 Environment-Based Configuration

The app **does not hardcode** any URL. The URL is configured per environment:

```dart
// lib/core/config/env.dart
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://api.hayatsecret.com',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '...',
  );
}
```

Build commands:
```bash
# For Hayat Secret production build:
flutter build windows \
  --dart-define=SUPABASE_URL=https://api.hayatsecret.com \
  --dart-define=SUPABASE_ANON_KEY=eyJ...

# For Company B's build (same codebase, different config):
flutter build windows \
  --dart-define=SUPABASE_URL=https://api.companyB.com \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

This means **one codebase, multiple branded builds**, each pointing to its own server.

### 4.2 Supabase Client Initialization

```dart
// lib/main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,        // more secure than implicit
    ),
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.warn,
    ),
  );
  
  runApp(const ProviderScope(child: HayatSecretApp()));
}
```

### 4.3 Connection Security

- **HTTPS only.** App refuses to connect to `http://` URLs.
- **Certificate pinning** (Phase 2): the app verifies the SSL certificate fingerprint to prevent MITM attacks.
- **JWT in memory, refresh token in secure storage:**
  - Access token: in-memory only (lost on restart, re-fetched via refresh)
  - Refresh token: `flutter_secure_storage` (encrypted by OS)
- **No anon key abuse:** the anon key is public knowledge. All security comes from RLS, not the anon key.

### 4.4 Mobile Offline Connection Handling

```dart
// Connection state stream
final connectivityStream = Connectivity().onConnectivityChanged;

// On connectivity change:
//   - Online → trigger pending visit sync
//   - Offline → show offline badge in UI, all writes go to local Drift
```

The mobile app **must work for at least 24 hours offline** without breaking. Field agents in basements / underground parking lose signal regularly.

---

## 5. White-Labeling Per Tenant

When you sell the system to Company B in another country:

### 5.1 What Changes Per Tenant
- **Server:** their own VPS
- **Domain:** their own subdomain
- **App branding:** logo, primary color, app name
- **App icon:** their logo
- **Splash screen:** their identity
- **Generated PDFs:** their letterhead

### 5.2 What Stays the Same
- The codebase (entire Flutter project)
- The database schema
- The business logic
- The UX flows

### 5.3 How to Brand a Build

A `branding.json` file per client, loaded at build time:

```json
{
  "appName": "Madar — Hayat Secret",
  "primaryColor": "#C9A961",
  "secondaryColor": "#1A1A1A",
  "logoAssetPath": "assets/branding/hayat_secret/logo.png",
  "splashAssetPath": "assets/branding/hayat_secret/splash.png",
  "companyName": "Hayat Secret",
  "companyTagline": "Mind, Body, Soul & Beyond",
  "supportEmail": "support@hayatsecret.com",
  "supportPhone": "+965-..."
}
```

A script generates platform-specific assets (icons, splash) from this config:
```bash
dart run flutter_launcher_icons:main -f branding/hayat_secret.yaml
dart run flutter_native_splash:create
flutter build windows --dart-define=BRANDING=hayat_secret
```

---

## 6. Provisioning a New Tenant on Their VPS

### 6.1 Manual Process (v1)

For each new client company:

```
1. Client provisions a VPS (you can guide them)
2. You SSH in, run the install script:
   - install docker
   - clone supabase/docker
   - configure .env with their credentials
   - docker compose up -d
   - configure nginx + ssl
3. Run all 30 migrations from supabase/migrations/
4. Create their initial tenant row + owner user
5. Create branded build of the Flutter app
6. Provide download/installers to their team
7. Document their credentials in a sealed handover
```

### 6.2 Future: Automated Onboarding Script

A bash + ansible script: input = domain name + admin email → output = fully configured Supabase + first tenant row + admin password.

---

## 7. Updates & Patches

When you ship a new version of the system:

### 7.1 Database Migrations
- New SQL migrations are added to `supabase/migrations/`
- On the tenant's VPS, run `supabase db push` (or apply via Studio)
- Migrations are designed to be **idempotent and reversible**

### 7.2 App Updates
- Build new app version
- Distribute via:
  - **Windows:** auto-updater via Squirrel/AppCenter (Phase 4)
  - **Android:** Play Store internal track, then production
  - **iOS:** TestFlight, then App Store
- For self-hosted tenants, you may distribute installers directly via signed downloads

### 7.3 Backward Compatibility
- Avoid breaking changes mid-version
- When unavoidable, force-update prompt in app
- Migration scripts must handle both pre- and post-change data

---

## 8. Security Considerations Specific to Self-Hosting

### 8.1 The Tenant Owns the Server
This means **they** are responsible for:
- OS updates (`apt update && apt upgrade`)
- Docker updates
- Firewall config
- Backup verification

**You** (system creator) provide:
- Maintenance contract (optional paid service)
- Patch notes when new versions ship
- Emergency response

### 8.2 Firewall Rules
```
ufw default deny incoming
ufw allow 22/tcp     # SSH (restrict to known IPs)
ufw allow 80/tcp     # HTTP (for Let's Encrypt renewal)
ufw allow 443/tcp    # HTTPS
# Postgres port 5432 NEVER exposed externally
ufw enable
```

### 8.3 SSH Hardening
- Disable password login (`PasswordAuthentication no`)
- Use SSH keys only
- Disable root login
- Move to non-standard port (optional, security through obscurity but reduces noise)
- Use `fail2ban` for brute-force protection

### 8.4 Postgres Access
- Only accessible via Docker internal network
- Database password not even known to the app — it goes through PostgREST + RLS
- Admin direct access via Studio (also IP-restricted) or temporary SSH tunnel for emergencies

---

## 9. The Connection String Itself — Where It Lives

To be crystal clear about how connection works:

```
The Flutter app NEVER has a Postgres connection string.

Flutter app
   │
   │  HTTPS to https://api.theirdomain.com
   │  Headers: Authorization: Bearer <user-jwt>
   │           apikey: <anon-key>
   ▼
Nginx (port 443)
   │
   │  HTTP to localhost:8000
   ▼
Kong (Supabase gateway)
   │
   │  Routes to /rest, /auth, /storage, /realtime
   ▼
PostgREST (port 3000)
   │
   │  Connects to Postgres with role=anon or authenticated
   │  Internal connection string in docker-compose
   ▼
PostgreSQL (port 5432, internal only)
   │
   │  Executes query, RLS filters rows by tenant_id
   ▼
Result returned up the stack
```

This layered approach means:
1. **No direct DB access from the app** — always through HTTP API
2. **RLS enforcement** at the database level — even if a JWT is stolen, it only sees that user's tenant
3. **Anon key is harmless on its own** — it just identifies the Supabase project, doesn't grant any data access
4. **JWT is the real credential** — short-lived (1 hour), refreshed via refresh token

---

## 10. Cost Estimate Per Tenant (Self-Hosted)

| Item | Monthly Cost |
|------|--------------|
| VPS (Hetzner CX22 or similar) | $10–$20 |
| Domain | $1 (annual averaged) |
| Off-site backup (Wasabi) | $1–$3 |
| Email service (Resend) | Free up to 3k emails, then $20/month |
| WhatsApp (Meta) | Pay-per-conversation, ~$0.03 each |
| **Total recurring** | **~$15–$45/month** |

A small fragrance company doing 150 contracts × ~5 WhatsApp/month = 750 conversations × $0.03 = ~$23/month for WhatsApp. Totalling ~$40–$70/month operational cost per tenant.
