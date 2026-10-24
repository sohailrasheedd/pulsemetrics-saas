-- ==============================================================================
-- PulseMetrics Multi-Tenant RLS Security Test Script (PostgreSQL / Supabase)
-- Path: supabase/tests/rls_policies.test.sql
-- ==============================================================================
-- This script validates Row-Level Security directly inside PostgreSQL by
-- simulating authenticated sessions using SET LOCAL "request.jwt.claims".
-- Can be executed directly in the Supabase SQL Editor or automated via pgTAP.
-- ==============================================================================

BEGIN;

-- 1. Setup isolated test tenants
INSERT INTO public.organizations (id, name, slug) VALUES 
('00000000-0000-0000-0000-000000000001', 'Tenant Alpha Corp', 'alpha-corp'),
('00000000-0000-0000-0000-000000000002', 'Tenant Beta LLC', 'beta-llc')
ON CONFLICT (id) DO NOTHING;

-- 2. Populate isolated records under each tenant
INSERT INTO public.subscriptions (id, org_id, customer_email, plan_tier, mrr_cents) VALUES 
('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000001', 'billing@alpha-corp.com', 'enterprise', 50000),
('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000002', 'finance@beta-llc.com', 'starter', 9900)
ON CONFLICT (id) DO NOTHING;

-- ==============================================================================
-- TEST CASE 1: Tenant Alpha Read Isolation
-- ==============================================================================
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "user-alpha-id", "app_metadata": {"org_id": "00000000-0000-0000-0000-000000000001"}}';

-- Must return only Tenant Alpha's subscription
SELECT 
  CASE WHEN count(*) = 1 THEN 'PASS: Tenant Alpha sees exactly 1 own record'
       ELSE 'FAIL: Unexpected count for Tenant Alpha'
  END AS test_result
FROM public.subscriptions;

-- Attempt to read Tenant Beta's row by specific ID: MUST RETURN 0 ROWS
SELECT 
  CASE WHEN count(*) = 0 THEN 'PASS: Cross-tenant query returned 0 rows (No leak)'
       ELSE 'FAIL: Cross-tenant data leaked!'
  END AS test_result
FROM public.subscriptions
WHERE id = '22222222-2222-2222-2222-222222222222';


-- ==============================================================================
-- TEST CASE 2: Cross-Tenant Insert Blockage
-- ==============================================================================
-- Tenant Alpha authenticated user attempts to inject row into Tenant Beta org
DO $$
BEGIN
  INSERT INTO public.subscriptions (org_id, customer_email, plan_tier, mrr_cents)
  VALUES ('00000000-0000-0000-0000-000000000002', 'malicious@spoof.com', 'enterprise', 999900);
  
  RAISE EXCEPTION 'SECURITY FAIL: Cross-tenant insert succeeded when it should have been blocked!';
EXCEPTION 
  WHEN insufficient_privilege OR check_violation THEN
    RAISE NOTICE 'PASS: Cross-tenant insert successfully blocked with RLS violation.';
END $$;


-- ==============================================================================
-- TEST CASE 3: Tenant Beta Verification
-- ==============================================================================
SET LOCAL "request.jwt.claims" = '{"sub": "user-beta-id", "app_metadata": {"org_id": "00000000-0000-0000-0000-000000000002"}}';

-- Tenant Beta must see only their own row
SELECT 
  CASE WHEN count(*) = 1 THEN 'PASS: Tenant Beta sees exactly 1 own record'
       ELSE 'FAIL: Unexpected count for Tenant Beta'
  END AS test_result
FROM public.subscriptions;

-- Clean teardown of test transaction
ROLLBACK;
