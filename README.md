# PulseMetrics — SaaS Revenue Telemetry Demo & RLS Architecture Reference

[![Live Demo](https://img.shields.io/badge/Demo-pulsemetrics--demo.vercel.app-06b6d4?style=for-the-badge&logo=vercel&logoColor=white)](https://pulsemetrics-demo.vercel.app)
[![Architecture](https://img.shields.io/badge/Architecture-Reference%20Design-8b5cf6?style=for-the-badge)](https://pulsemetrics-demo.vercel.app)
[![Security](https://img.shields.io/badge/Security-PostgreSQL%20RLS%20Schema-10b981?style=for-the-badge&logo=postgresql&logoColor=white)](https://pulsemetrics-demo.vercel.app)
[![Stack](https://img.shields.io/badge/Stack-HTML5%20%7C%20Tailwind%20%7C%20Vanilla%20JS-38bdf8?style=for-the-badge)](https://pulsemetrics-demo.vercel.app)

> **Project Notice:** PulseMetrics is a reference and demonstration project. The live web application is a static client-side dashboard powered by structured mock data (`data/mockData.js`). The repository also provides a reference implementation of a multi-tenant PostgreSQL Row-Level Security (RLS) schema migration and accompanying verification test scripts.

---

## 📌 Project Scope: What Is and Is Not Implemented

### What Is Implemented
- **Interactive Telemetry Dashboard (Client-Side):** A responsive UI displaying MRR, ARR, churn, and cohort retention curves using Tailwind CSS and Chart.js.
- **Reference PostgreSQL RLS Migration (`supabase/migrations/`):** A standalone SQL migration defining multi-tenant tables (`organizations`, `tenant_memberships`, `subscriptions`, `revenue_events`) with Row-Level Security enabled.
- **Optimized Tenant Lookup Function:** A `STABLE` function (`current_user_org_id()`) that resolves tenant scope from `auth.jwt() -> 'app_metadata' ->> 'org_id'` with a fallback to `tenant_memberships`.
- **Compound Idempotency Constraint:** Scoped unique constraint `(org_id, idempotency_key)` on `revenue_events` to prevent cross-tenant key enumeration.
- **Database Security Test Suite (`supabase/tests/database/`):** A pgTAP-compatible SQL test script asserting tenant isolation, cross-tenant mutation blocks, and role permissions.
- **In-Memory Mock Test (`tests/unit/`):** A lightweight Vitest unit test exercising an in-memory client mock.

### What Is NOT Implemented (UI Mockup Only)
- **Live Stripe Webhook Ingestion:** No live Stripe API keys or active webhook listeners are running. Webhook pipeline diagrams represent the intended backend design.
- **Dynamic Database Connection in Dashboard:** The browser dashboard runs entirely on static seed data (`mockData.js`) and does not establish live connections to a Supabase or PostgreSQL instance.
- **Predictive ML Churn Models:** Churn risk flags in the UI are pre-calculated demo values.

---

## 🏗️ Multi-Tenant RLS Architecture

```
                  Client Request with Supabase Auth JWT
                                    │
                                    ▼
       ┌────────────────────────────────────────────────────────┐
       │             PostgreSQL Query Planner                   │
       │                                                        │
       │  InitPlan: (SELECT public.current_user_org_id())       │
       │    1. Inspects auth.jwt() -> 'app_metadata' ->> 'org_id'│
       │    2. Fallback: tenant_memberships (earliest membership)│
       └────────────────────────────┬───────────────────────────┘
                                    │
                    Evaluated Once per Statement
                                    │
                                    ▼
         ┌─────────────────────────────────────────────────────┐
         │             Row-Level Security Policies             │
         │                                                     │
         │  USING (org_id = InitPlan)                          │
         │  WITH CHECK (org_id = InitPlan)                     │
         └──────────────────────────┬──────────────────────────┘
                                    │
                                    ▼
         ┌─────────────────────────────────────────────────────┐
         │              Table Data (Index Scan)                │
         │                                                     │
         │  idx_subscriptions_org_id (B-tree on org_id)        │
         └─────────────────────────────────────────────────────┘
```

### Architectural Decisions
1. **`STABLE` Function & InitPlan:** Marking `current_user_org_id()` as `STABLE` informs PostgreSQL that its return value remains constant throughout a single query execution. Calling it as `(SELECT public.current_user_org_id())` in policies allows the planner to execute it as an InitPlan (once per statement), rather than re-evaluating it for each scanned row.
2. **Schema Qualification:** The function specifies `SET search_path = public, pg_temp` to prevent search-path hijacking under `SECURITY DEFINER`.
3. **Compound Unique Keys:** Webhook idempotency keys are constrained by `UNIQUE (org_id, idempotency_key)`, ensuring tenant isolation in asynchronous ingestion ledgers.

---

## 🧪 How to Run Tests

### 1. Database RLS Test Suite (pgTAP)
The database test suite requires Docker and the Supabase CLI:

```bash
# Start local Supabase container stack
supabase start

# Execute the pgTAP RLS policy test suite
supabase test db
```

*Note: If running in an environment without Docker or Supabase CLI, this test cannot be executed locally.*

### 2. In-Memory Mock Test (Vitest)
A unit test exercising client-side mock guard logic can be executed via Node.js:

```bash
# Install dependencies
npm install

# Run unit tests
npm test
```

---

## ⚠️ Known Limitations

1. **Multi-Organization Users:** If a user belongs to multiple organizations and does not have an explicit `org_id` claim inside `auth.jwt() -> app_metadata`, the fallback query resolves to their earliest membership (`ORDER BY created_at ASC LIMIT 1`). In multi-tenant applications with account switching, the application layer must ensure the active tenant is encoded into the session JWT.
2. **Service Role Trust Boundary:** The `service_role` key bypasses RLS by design in Supabase. Backend services (e.g. Stripe webhook consumers) must sanitize tenant parameters before mutating data.
3. **Demo Scope:** This repository is intended as an architectural reference and code demonstration, not a turnkey SaaS platform.

---

## 🚀 Local Development (Dashboard UI)

To run the interactive UI dashboard locally:

```bash
# Using Python built-in server
python -m http.server 3000

# Or using npx
npx serve .
```

Open `http://localhost:3000` in any modern web browser.

---

## 📁 Repository Structure

```
pulsemetrics-saas/
├── data/
│   └── mockData.js                       # Mock telemetry datasets for the UI
├── supabase/
│   ├── migrations/
│   │   └── 20241020000001_multi_tenant_rls.sql  # Reference RLS schema migration
│   └── tests/
│       └── database/
│           └── rls_policies.test.sql     # pgTAP database isolation test suite
├── tests/
│   └── unit/
│       └── tenant-guard.mock.test.ts     # In-memory mock unit test
├── index.html                            # Static dashboard user interface
├── package.json                          # Node test scripts and dev dependencies
├── vitest.config.ts                      # Vitest configuration
├── vercel.json                           # Vercel deployment headers
└── README.md                             # Architectural documentation
```

---

## 📄 License
Released under the [MIT License](LICENSE).
