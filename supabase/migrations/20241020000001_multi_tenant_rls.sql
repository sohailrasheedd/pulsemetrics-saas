-- ==============================================================================
-- PulseMetrics Multi-Tenant PostgreSQL Row-Level Security (RLS) Migration
-- Version: 20241020000001_multi_tenant_rls.sql
-- Architecture: Multi-tenant SaaS with indexed org_id and STABLE lookup caching
-- ==============================================================================

-- 1. Base Organizations / Tenants Table
CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    plan TEXT NOT NULL DEFAULT 'starter',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. Organization Memberships (Maps auth.users to tenants with RBAC)
CREATE TABLE IF NOT EXISTS public.tenant_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(org_id, user_id)
);

-- High-performance index for fast membership and tenant resolution
CREATE INDEX IF NOT EXISTS idx_tenant_memberships_user_org 
ON public.tenant_memberships (user_id, org_id);

-- 3. Core Tenant Data Tables (Bounded by org_id)

-- Subscriptions Table (Customer billing and telemetry)
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    stripe_subscription_id TEXT UNIQUE,
    stripe_customer_id TEXT,
    customer_email TEXT NOT NULL,
    plan_tier TEXT NOT NULL,
    mrr_cents INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'active', -- 'active', 'past_due', 'canceled'
    current_period_end TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- B-Tree index on org_id ensures RLS filter operations run via index scans
CREATE INDEX IF NOT EXISTS idx_subscriptions_org_id 
ON public.subscriptions (org_id);

-- Revenue & Churn Events Table (Webhook ingestion ledger)
CREATE TABLE IF NOT EXISTS public.revenue_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL, -- 'mrr.new', 'mrr.expansion', 'mrr.contraction', 'churn'
    amount_cents INTEGER NOT NULL,
    idempotency_key TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    -- Compound unique constraint scoped to tenant to prevent cross-tenant key sniffing
    CONSTRAINT uq_revenue_events_org_idempotency UNIQUE (org_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_revenue_events_org_id 
ON public.revenue_events (org_id);


-- ==============================================================================
-- 4. High-Performance STABLE Tenant Lookup Function
-- ==============================================================================
-- Marking this function STABLE informs the PostgreSQL query optimizer that within
-- a single query / transaction, the returned org_id for auth.uid() remains invariant.
-- Wrapping function calls as (SELECT public.current_user_org_id()) in policies allows
-- PostgreSQL to optimize it as an InitPlan, evaluating it once rather than per-row.
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.current_user_org_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  -- Step 1: High-speed extraction directly from signed JWT app_metadata claim
  SELECT COALESCE(
    NULLIF((auth.jwt() -> 'app_metadata' ->> 'org_id'), '')::uuid,
    (
      -- Step 2: Fallback to indexed tenant memberships table for authenticated user
      SELECT org_id
      FROM public.tenant_memberships
      WHERE user_id = auth.uid()
      ORDER BY created_at ASC
      LIMIT 1
    )
  );
$$;

-- Grant execution permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.current_user_org_id() TO authenticated;


-- ==============================================================================
-- 5. Enable Row-Level Security (RLS) on All Tenant Tables
-- ==============================================================================
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.revenue_events ENABLE ROW LEVEL SECURITY;


-- ==============================================================================
-- 6. Declare Strict Tenant Isolation Policies
-- ==============================================================================

-- Organizations Table Policies
CREATE POLICY "Tenant Isolation: Select organization"
ON public.organizations
FOR SELECT
TO authenticated
USING (id = (SELECT public.current_user_org_id()));

CREATE POLICY "Tenant Isolation: Update organization"
ON public.organizations
FOR UPDATE
TO authenticated
USING (id = (SELECT public.current_user_org_id()))
WITH CHECK (id = (SELECT public.current_user_org_id()));

-- Tenant Memberships Policies
CREATE POLICY "Tenant Isolation: Select memberships"
ON public.tenant_memberships
FOR SELECT
TO authenticated
USING (org_id = (SELECT public.current_user_org_id()));

-- Subscriptions Table Policies (Full CRUD isolation)
CREATE POLICY "Tenant Isolation: Select subscriptions"
ON public.subscriptions
FOR SELECT
TO authenticated
USING (org_id = (SELECT public.current_user_org_id()));

CREATE POLICY "Tenant Isolation: Insert subscriptions"
ON public.subscriptions
FOR INSERT
TO authenticated
WITH CHECK (org_id = (SELECT public.current_user_org_id()));

CREATE POLICY "Tenant Isolation: Update subscriptions"
ON public.subscriptions
FOR UPDATE
TO authenticated
USING (org_id = (SELECT public.current_user_org_id()))
WITH CHECK (org_id = (SELECT public.current_user_org_id()));

CREATE POLICY "Tenant Isolation: Delete subscriptions"
ON public.subscriptions
FOR DELETE
TO authenticated
USING (org_id = (SELECT public.current_user_org_id()));

-- Revenue Events Table Policies (Append-only immutable audit ledger)
CREATE POLICY "Tenant Isolation: Select revenue events"
ON public.revenue_events
FOR SELECT
TO authenticated
USING (org_id = (SELECT public.current_user_org_id()));

CREATE POLICY "Tenant Isolation: Insert revenue events"
ON public.revenue_events
FOR INSERT
TO authenticated
WITH CHECK (org_id = (SELECT public.current_user_org_id()));


-- ==============================================================================
-- 7. Backend Service-Role Webhook Exemption Note
-- ==============================================================================
-- In Supabase / PostgreSQL, the 'service_role' key intentionally bypasses RLS.
-- This allows backend worker processes (e.g., Stripe webhook event consumers,
-- background sync daemons, and administrative crons) to insert and update across
-- any tenant using transactional ACID semantics, while normal authenticated API
-- tokens remain strictly locked into their own current_user_org_id().
-- ==============================================================================
