import { describe, it, expect, beforeEach } from 'vitest';

/**
 * Unit tests against an in-memory mock. These do NOT exercise Postgres RLS.
 * See supabase/tests/database for real RLS tests.
 * 
 * Path: tests/unit/tenant-guard.mock.test.ts
 */

export const TENANT_A_ORG_ID = '00000000-0000-0000-0000-000000000001';
export const TENANT_B_ORG_ID = '00000000-0000-0000-0000-000000000002';

export interface SubscriptionRecord {
  id: string;
  org_id: string;
  customer_email: string;
  plan_tier: string;
  mrr_cents: number;
  status: string;
}

// In-memory mock simulating tenant-scoped client behavior
function createMockClient(orgId: string, isServiceRole: boolean = false) {
  return {
    from: (table: string) => ({
      select: (cols: string = '*') => ({
        eq: async (column: string, val: any) => {
          if (!isServiceRole && column === 'id' && val === 'sub_beta_01' && orgId === TENANT_A_ORG_ID) {
            return { data: [], error: null, count: 0 };
          }
          if (isServiceRole) {
            return { data: [{ id: val, org_id: TENANT_A_ORG_ID }], error: null, count: 1 };
          }
          return { data: [{ id: val, org_id: orgId }], error: null, count: 1 };
        },
        execute: async () => {
          if (isServiceRole) {
            return {
              data: [
                { id: 'sub_alpha_01', org_id: TENANT_A_ORG_ID },
                { id: 'sub_beta_01', org_id: TENANT_B_ORG_ID },
              ],
              error: null,
            };
          }
          return {
            data: [{ id: `sub_${orgId === TENANT_A_ORG_ID ? 'alpha' : 'beta'}_01`, org_id: orgId }],
            error: null,
          };
        },
      }),

      insert: async (payload: Partial<SubscriptionRecord>) => {
        if (!isServiceRole && payload.org_id && payload.org_id !== orgId) {
          return {
            data: null,
            error: {
              message: 'new row violates mock security rule for table "subscriptions"',
              code: '42501',
              details: `Failing row contains (org_id=${payload.org_id})`,
              hint: null,
            },
          };
        }
        return { data: { ...payload, id: 'sub_new_ok' }, error: null };
      },
    }),
  };
}

describe('In-Memory Mock Tenant Isolation Unit Suite', () => {
  let tenantAClient: ReturnType<typeof createMockClient>;
  let tenantBClient: ReturnType<typeof createMockClient>;
  let serviceRoleClient: ReturnType<typeof createMockClient>;

  beforeEach(() => {
    tenantAClient = createMockClient(TENANT_A_ORG_ID, false);
    tenantBClient = createMockClient(TENANT_B_ORG_ID, false);
    serviceRoleClient = createMockClient(TENANT_A_ORG_ID, true);
  });

  it('returns zero rows when mock Tenant A queries for mock Tenant B id', async () => {
    const response = await tenantAClient.from('subscriptions').select('*').eq('id', 'sub_beta_01');
    expect(response.error).toBeNull();
    expect(response.data).toHaveLength(0);
    expect(response.data).toEqual([]);
  });

  it('returns own tenant records for mock tenant session', async () => {
    const resA = await tenantAClient.from('subscriptions').select('*').execute();
    expect(resA.error).toBeNull();
    expect(resA.data.every((r: any) => r.org_id === TENANT_A_ORG_ID)).toBe(true);

    const resB = await tenantBClient.from('subscriptions').select('*').execute();
    expect(resB.error).toBeNull();
    expect(resB.data.every((r: any) => r.org_id === TENANT_B_ORG_ID)).toBe(true);
  });

  it('blocks insert when mock client attempts to write foreign org_id', async () => {
    const hostilePayload: Partial<SubscriptionRecord> = {
      org_id: TENANT_B_ORG_ID,
      customer_email: 'attacker@spoofed.com',
      mrr_cents: 999900,
    };

    const writeResponse = await tenantAClient.from('subscriptions').insert(hostilePayload);
    expect(writeResponse.data).toBeNull();
    expect(writeResponse.error).not.toBeNull();
    expect(writeResponse.error.code).toBe('42501');
    expect(writeResponse.error.message).toContain('violates mock security rule');
  });

  it('allows mock service-role client to write across orgs for webhooks', async () => {
    const webhookPayload: Partial<SubscriptionRecord> = {
      org_id: TENANT_A_ORG_ID,
      customer_email: 'newpayer@tenant-a.com',
      mrr_cents: 12000,
    };

    const webhookResult = await serviceRoleClient.from('subscriptions').insert(webhookPayload);
    expect(webhookResult.error).toBeNull();
    expect(webhookResult.data?.id).toBeDefined();
  });
});
