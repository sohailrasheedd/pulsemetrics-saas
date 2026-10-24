-- ==============================================================================
-- PulseMetrics Multi-Tenant PostgreSQL Row-Level Security (RLS) Migration
-- Version: 20241020000001_multi_tenant_rls.sql
-- Architecture: Reference multi-tenant SaaS schema with org_id isolation and STABLE InitPlan caching
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
-- Note: In production Supabase environments with the auth schema present,
-- user_id references auth.users(id) ON DELETE CASCADE.
CREATE TABLE IF NOT EXISTS public.tenant_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(org_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_tenant_memberships_user_org 
ON public.tenant_memberships (user_id, org_id);

-- 3. Core Tenant Data Tables (Bounded by org_id)

-- Subscriptions Table
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    stripe_subscription_id TEXT,
    stripe_customer_id TEXT,
    customer_email TEXT NOT NULL,
    plan_tier TEXT NOT NULL,
    mrr_cents INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'active', -- 'active', 'past_due', 'canceled'
    current_period_end TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    -- Scoped compound unique constraint prevents cross-tenant enumeration
    CONSTRAINT uq_subscriptions_org_stripe_sub UNIQUE (org_id, stripe_subscription_id)
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_org_id 
ON public.subscriptions (org_id);

-- Revenue & Churn Events Table (Immutable append-only ledger)
CREATE TABLE IF NOT EXISTS public.revenue_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL, -- 'mrr.new', 'mrr.expansion', 'mrr.contraction', 'churn'
    amount_cents INTEGER NOT NULL,
    idempotency_key TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    -- Compound unique constraint scoped to org_id prevents cross-tenant key collision/sniffing
    CONSTRAINT uq_revenue_events_org_idempotency UNIQUE (org_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_revenue_events_org_id 
ON public.revenue_events (org_id);


-- ==============================================================================
-- 4. STABLE Tenant Lookup Function
-- ==============================================================================
-- Technical Explanation:
-- PostgreSQL functions default to VOLATILE. Marking this function STABLE indicates
-- that within a single statement, the return value is constant for the active transaction.
-- When called in policies as (SELECT public.current_user_org_id()), the PostgreSQL
-- query optimizer evaluates the sub-select as an InitPlan (calculated once per execution
-- plan rather than per evaluated row), allowing row filtering to utilize the B-tree index on org_id.
--
-- Known Limitation:
-- If a user has multiple tenant memberships and no JWT org_id claim is set, the fallback
-- resolves deterministically to the earliest membership (ORDER BY created_at ASC LIMIT 1).
-- Multi-organization users must have active organization selection encoded in auth.jwt().
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.current_user_org_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(
    -- 1. Safely extract and validate UUID from JWT app_metadata claim
    CASE 
      WHEN auth.jwt() -> 'app_metadata' ->> 'org_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      THEN (auth.jwt() -> 'app_metadata' ->> 'org_id')::uuid
      ELSE NULL
    END,
    -- 2. Fallback to membership table lookup for authenticated user (earliest organization)
    (
      SELECT tm.org_id
      FROM public.tenant_memberships tm
      WHERE tm.user_id = auth.uid()
      ORDER BY tm.created_at ASC
      LIMIT 1
    )
  );
$$;

-- Function security hardening: restrict execution rights strictly to authenticated sessions
REVOKE EXECUTE ON FUNCTION public.current_user_org_id() FROM PUBLIC, anon;
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
-- Every policy wraps the function call in (SELECT public.current_user_org_id())
-- to trigger PostgreSQL InitPlan evaluation.
-- ==============================================================================

-- Organizations Table Policies
-- SELECT: Authenticated members can only read their own organization record.
CREATE POLICY "Tenant Isolation: Select organization"
ON public.organizations
FOR SELECT
TO authenticated
USING (id = (SELECT public.current_user_org_id()));

-- UPDATE: Authenticated members can update their own organization settings.
CREATE POLICY "Tenant Isolation: Update organization"
ON public.organizations
FOR UPDATE
TO authenticated
USING (id = (SELECT public.current_user_org_id()))
WITH CHECK (id = (SELECT public.current_user_org_id()));
-- Note: INSERT and DELETE on organizations are intentionally restricted to service_role / platform admin.

-- Tenant Memberships Policies
-- SELECT: Authenticated users can view team members belonging to their active organization.
CREATE POLICY "Tenant Isolation: Select memberships"
ON public.tenant_memberships
FOR SELECT
TO authenticated
USING (org_id = (SELECT public.current_user_org_id()));
-- Note: Membership invitations, role updates, and deletions are managed through backend admin endpoints via service_role.

-- Subscriptions Table Policies (Full CRUD Isolation)
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

-- Revenue Events Table Policies (Append-Only Immutable Ledger)
-- SELECT: Authenticated users can inspect revenue events for their own organization.
CREATE POLICY "Tenant Isolation: Select revenue events"
ON public.revenue_events
FOR SELECT
TO authenticated
USING (org_id = (SELECT public.current_user_org_id()));

-- INSERT: Authenticated users can append new revenue events for their own organization.
CREATE POLICY "Tenant Isolation: Insert revenue events"
ON public.revenue_events
FOR INSERT
TO authenticated
WITH CHECK (org_id = (SELECT public.current_user_org_id()));
-- Note: UPDATE and DELETE policies are intentionally omitted. revenue_events is an immutable financial ledger.


-- ==============================================================================
-- 7. Backend Service-Role Webhook Exemption Note
-- ==============================================================================
-- In Supabase / PostgreSQL, the service_role key intentionally bypasses RLS.
-- This allows backend worker processes (e.g. Stripe webhook handlers, billing cron
-- daemons, and administrative tasks) to read and write across any tenant partition.
-- Authenticated user clients using standard JWTs remain strictly bound by RLS policies.
-- ==============================================================================
