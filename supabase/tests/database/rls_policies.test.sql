-- ==============================================================================
-- PulseMetrics Multi-Tenant PostgreSQL pgTAP Security Test Suite
-- Path: supabase/tests/database/rls_policies.test.sql
-- ==============================================================================
-- Standard pgTAP verification suite designed to run via:
--   supabase test db
-- ==============================================================================

BEGIN;

-- Load pgTAP extension (pre-installed in Supabase test environment)
CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(16);

-- ==============================================================================
-- Test Fixtures & Seed Setup (Executed as Superuser / postgres role)
-- ==============================================================================

-- Setup Test RFC-4122 UUIDs
\set org_a 'a0000000-0000-0000-0000-000000000001'
\set org_b 'b0000000-0000-0000-0000-000000000002'
\set user_a '10000000-0000-0000-0000-000000000001'
\set user_b '20000000-0000-0000-0000-000000000002'
\set user_fallback '30000000-0000-0000-0000-000000000003'
\set user_unlinked '40000000-0000-0000-0000-000000000004'

\set sub_a '11111111-1111-1111-1111-111111111111'
\set sub_b '22222222-2222-2222-2222-222222222222'

-- Safely clean only scoped test fixtures without destructive global truncate
DELETE FROM public.revenue_events WHERE org_id IN ('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002');
DELETE FROM public.subscriptions WHERE org_id IN ('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002');
DELETE FROM public.tenant_memberships WHERE org_id IN ('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002');
DELETE FROM public.organizations WHERE id IN ('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002');

-- 1. Insert Organizations
INSERT INTO public.organizations (id, name, slug) VALUES 
('a0000000-0000-0000-0000-000000000001', 'Tenant Alpha', 'tenant-alpha'),
('b0000000-0000-0000-0000-000000000002', 'Tenant Beta', 'tenant-beta');

-- 2. Insert Memberships
INSERT INTO public.tenant_memberships (id, org_id, user_id, role) VALUES 
('m0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'owner'),
('m0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'owner'),
('m0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000003', 'member');

-- 3. Insert Subscriptions
INSERT INTO public.subscriptions (id, org_id, customer_email, plan_tier, mrr_cents) VALUES 
('11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000001', 'customer@alpha.com', 'enterprise', 50000),
('22222222-2222-2222-2222-222222222222', 'b0000000-0000-0000-0000-000000000002', 'customer@beta.com', 'starter', 9900);

-- 4. Insert Revenue Events
INSERT INTO public.revenue_events (org_id, event_type, amount_cents, idempotency_key) VALUES 
('a0000000-0000-0000-0000-000000000001', 'mrr.new', 50000, 'evt_shared_key_001'),
('b0000000-0000-0000-0000-000000000002', 'mrr.new', 9900, 'evt_shared_key_001');


-- ==============================================================================
-- TEST 1: Tenant A sees only Tenant A rows across tables (4 assertions)
-- ==============================================================================
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "10000000-0000-0000-0000-000000000001", "role": "authenticated", "app_metadata": {"org_id": "a0000000-0000-0000-0000-000000000001"}}';

SELECT results_eq(
  'SELECT id FROM public.subscriptions',
  'VALUES (''11111111-1111-1111-1111-111111111111''::uuid)',
  'Tenant A can only see Tenant A subscriptions'
);

SELECT results_eq(
  'SELECT org_id FROM public.revenue_events',
  'VALUES (''a0000000-0000-0000-0000-000000000001''::uuid)',
  'Tenant A can only see Tenant A revenue events'
);

SELECT results_eq(
  'SELECT id FROM public.organizations',
  'VALUES (''a0000000-0000-0000-0000-000000000001''::uuid)',
  'Tenant A can only see Tenant A organization'
);

SELECT results_eq(
  'SELECT org_id FROM public.tenant_memberships',
  'VALUES (''a0000000-0000-0000-0000-000000000001''::uuid), (''a0000000-0000-0000-0000-000000000001''::uuid)',
  'Tenant A can only see Tenant A memberships'
);

-- ==============================================================================
-- TEST 2: Tenant A selecting Tenant B row by exact ID returns 0 rows (1 assertion)
-- ==============================================================================
SELECT is_empty(
  'SELECT * FROM public.subscriptions WHERE id = ''22222222-2222-2222-2222-222222222222''',
  'Tenant A selecting Tenant B subscription by ID returns 0 rows'
);

-- ==============================================================================
-- TEST 3: Tenant A inserting with Tenant B org_id throws 42501 (2 assertions)
-- ==============================================================================
SELECT throws_ok(
  'INSERT INTO public.subscriptions (org_id, customer_email, plan_tier, mrr_cents) VALUES (''b0000000-0000-0000-0000-000000000002'', ''spoof@test.com'', ''scale'', 1000)',
  '42501',
  NULL,
  'Tenant A insert into Tenant B subscriptions fails with 42501 RLS check violation'
);

SELECT throws_ok(
  'INSERT INTO public.revenue_events (org_id, event_type, amount_cents, idempotency_key) VALUES (''b0000000-0000-0000-0000-000000000002'', ''mrr.expansion'', 1000, ''evt_spoof_01'')',
  '42501',
  NULL,
  'Tenant A insert into Tenant B revenue_events fails with 42501 RLS check violation'
);

-- ==============================================================================
-- TEST 4: Tenant A UPDATE and DELETE on Tenant B rows affect 0 rows (1 assertion)
-- ==============================================================================
UPDATE public.subscriptions SET customer_email = 'hacked@beta.com' WHERE id = '22222222-2222-2222-2222-222222222222';
DELETE FROM public.subscriptions WHERE id = '22222222-2222-2222-2222-222222222222';

RESET ROLE;
-- Superuser verification that Tenant B record was not mutated or deleted
SELECT results_eq(
  'SELECT customer_email FROM public.subscriptions WHERE id = ''22222222-2222-2222-2222-222222222222''',
  'VALUES (''customer@beta.com''::text)',
  'Tenant B row remains untouched after Tenant A attempted update/delete'
);

-- ==============================================================================
-- TEST 5: Tenant A cannot move its own row to Tenant B org_id via UPDATE (1 assertion)
-- ==============================================================================
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "10000000-0000-0000-0000-000000000001", "role": "authenticated", "app_metadata": {"org_id": "a0000000-0000-0000-0000-000000000001"}}';

SELECT throws_ok(
  'UPDATE public.subscriptions SET org_id = ''b0000000-0000-0000-0000-000000000002'' WHERE id = ''11111111-1111-1111-1111-111111111111''',
  '42501',
  NULL,
  'Tenant A cannot migrate own subscription to Tenant B via UPDATE (WITH CHECK failure)'
);

-- ==============================================================================
-- TEST 6: Anon role sees 0 rows (2 assertions)
-- ==============================================================================
SET LOCAL ROLE anon;
RESET "request.jwt.claims";

SELECT is_empty(
  'SELECT * FROM public.subscriptions',
  'Anon role sees 0 rows in subscriptions'
);

SELECT is_empty(
  'SELECT * FROM public.revenue_events',
  'Anon role sees 0 rows in revenue_events'
);

-- ==============================================================================
-- TEST 7: Membership fallback path (2 assertions)
-- ==============================================================================
-- User 3 has no JWT claim, but belongs to Tenant Alpha in tenant_memberships
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "30000000-0000-0000-0000-000000000003", "role": "authenticated"}';

SELECT results_eq(
  'SELECT id FROM public.subscriptions',
  'VALUES (''11111111-1111-1111-1111-111111111111''::uuid)',
  'User with no JWT claim falls back to membership row and sees Tenant Alpha records'
);

-- User 4 has no JWT claim and no membership row -> 0 rows
SET LOCAL "request.jwt.claims" = '{"sub": "40000000-0000-0000-0000-000000000004", "role": "authenticated"}';
SELECT is_empty(
  'SELECT * FROM public.subscriptions',
  'Unlinked user with no membership and no JWT claim sees 0 rows'
);

-- ==============================================================================
-- TEST 8: Compound idempotency key uniqueness per org (1 assertion)
-- ==============================================================================
RESET ROLE;
-- Duplicate insert in same org fails with 23505 unique violation
SELECT throws_ok(
  'INSERT INTO public.revenue_events (org_id, event_type, amount_cents, idempotency_key) VALUES (''a0000000-0000-0000-0000-000000000001'', ''mrr.expansion'', 500, ''evt_shared_key_001'')',
  '23505',
  NULL,
  'Duplicate idempotency_key within the same org fails with 23505 unique constraint violation'
);

-- ==============================================================================
-- TEST 9: Service role / BYPASSRLS capability (1 assertion)
-- ==============================================================================
SET LOCAL ROLE service_role;
SELECT lives_ok(
  'INSERT INTO public.subscriptions (org_id, customer_email, plan_tier, mrr_cents) VALUES (''b0000000-0000-0000-0000-000000000002'', ''webhook@service.com'', ''scale'', 25000)',
  'Service role with BYPASSRLS can insert across tenants for background webhook ingestion'
);

-- ==============================================================================
-- TEST 10: Anon cannot execute current_user_org_id() (1 assertion)
-- ==============================================================================
SET LOCAL ROLE anon;
SELECT throws_ok(
  'SELECT public.current_user_org_id()',
  '42501',
  NULL,
  'Anon cannot execute current_user_org_id() (permission denied)'
);

-- Reset role back to postgres/superuser before finish
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
