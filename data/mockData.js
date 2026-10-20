/**
 * PulseMetrics — Centralized Mock Data Layer
 * Production-grade mock telemetry for US & UK enterprise SaaS demos.
 */

window.PulseMockData = {
  // 1. Executive KPIs with realistic variance
  kpis: {
    usd: {
      mrr: 142850,
      arr: 1714200,
      activeUsers: 8420,
      payingAccounts: 258,
      nrr: 114.2,
      logoChurn: 0.82,
      revenueChurn: -1.4, // Net negative churn due to expansion
      arpu: 940,
      ltv: 4250,
      cac: 680,
      ltvCacRatio: 6.2,
      runwayMonths: 28,
      quickRatio: 4.1
    },
    gbp: {
      mrr: 112137,
      arr: 1345647,
      activeUsers: 8420,
      payingAccounts: 258,
      nrr: 114.2,
      logoChurn: 0.82,
      revenueChurn: -1.4,
      arpu: 738,
      ltv: 3336,
      cac: 534,
      ltvCacRatio: 6.2,
      runwayMonths: 28,
      quickRatio: 4.1
    }
  },

  // 2. Trailing Timeframe Series (Natural SaaS Growth with realistic dips)
  timeframes: {
    '30d': {
      labels: ['Sep 14', 'Sep 19', 'Sep 24', 'Sep 29', 'Oct 04', 'Oct 09', 'Oct 13'],
      mrr: [136200, 137800, 137100, 139400, 140800, 141900, 142850],
      churn: [0.94, 0.91, 0.93, 0.88, 0.85, 0.84, 0.82],
      arpu: [910, 915, 918, 924, 930, 935, 940]
    },
    '90d': {
      labels: ['Jul 2026', 'Aug 2026', 'Sep 2026', 'Oct 2026'],
      mrr: [112000, 124800, 134200, 142850],
      churn: [1.2, 0.95, 0.88, 0.82],
      arpu: [780, 840, 890, 940]
    },
    'ytd': {
      labels: ['Jan 2026', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct 2026'],
      mrr: [62000, 71200, 78500, 86400, 96500, 104200, 112000, 124800, 134200, 142850],
      churn: [2.1, 1.9, 1.8, 1.6, 1.4, 1.3, 1.2, 0.95, 0.88, 0.82],
      arpu: [540, 580, 620, 670, 710, 750, 780, 840, 890, 940]
    }
  },

  // 3. Cohort Retention Matrix (Trailing 6 Months)
  cohorts: [
    { cohort: 'May 2026', size: '142 accts', logo: [100, 97.8, 96.2, 95.1, 94.4, 93.8, 93.2], ndr: [100, 102.4, 106.1, 109.4, 112.8, 115.3, 118.2] },
    { cohort: 'Jun 2026', size: '168 accts', logo: [100, 98.2, 97.0, 96.4, 95.8, 95.2, null], ndr: [100, 104.1, 108.3, 111.0, 114.2, 116.8, null] },
    { cohort: 'Jul 2026', size: '184 accts', logo: [100, 98.9, 97.8, 96.9, 96.1, null, null], ndr: [100, 105.2, 109.8, 113.4, 117.1, null, null] },
    { cohort: 'Aug 2026', size: '210 accts', logo: [100, 98.5, 97.4, 96.5, null, null, null], ndr: [100, 103.8, 107.5, 112.0, null, null, null] },
    { cohort: 'Sep 2026', size: '235 accts', logo: [100, 99.1, 98.2, null, null, null, null], ndr: [100, 106.3, 111.5, null, null, null, null] },
    { cohort: 'Oct 2026', size: '258 accts', logo: [100, 99.4, null, null, null, null, null], ndr: [100, 107.8, null, null, null, null, null] },
  ],

  // 4. Enterprise Accounts Directory
  accounts: [
    {
      id: 'cloudscale',
      name: 'CloudScale Systems Inc.',
      domain: 'cloudscale.io',
      location: 'San Francisco, CA (US)',
      region: 'US',
      plan: 'ENTERPRISE PRO',
      tierBadge: 'bg-violet-500/20 text-violet-300 border-violet-500/30',
      initials: 'CS',
      initialsColor: 'bg-sky-500/20 text-sky-400',
      badge: 'ACTIVE SUBSCRIBER',
      badgeColor: 'emerald',
      stripeId: 'cus_SF_9824219',
      mrrUsd: 2400,
      mrrGbp: 1880,
      billing: 'Annual Net-30 ($28,800)',
      seats: '48 / 50 seats',
      seatPct: 96,
      health: 98,
      healthComment: 'Super Active (4.2k daily API calls)',
      churnRisk: 0.2,
      riskLabel: '0.2% Low',
      riskClass: 'bg-emerald-500/10 text-emerald-400',
      gateway: 'Stripe US (ACH Debit)',
      renewal: 'Nov 14, 2026',
      apiVolume: '1,480,210 Total Requests',
      latency: '38ms',
      errRate: '0.002%',
      sparkline: [180, 210, 230, 195, 240, 275, 290]
    },
    {
      id: 'finflow',
      name: 'FinFlow Capital Ltd',
      domain: 'finflow.co.uk',
      location: 'London, EC2 (UK)',
      region: 'UK',
      plan: 'BUSINESS SCALE',
      tierBadge: 'bg-sky-500/20 text-sky-300 border-sky-500/30',
      initials: 'FF',
      initialsColor: 'bg-indigo-500/20 text-indigo-400',
      badge: 'ACTIVE SUBSCRIBER',
      badgeColor: 'emerald',
      stripeId: 'cus_UK_8491023',
      mrrUsd: 1850,
      mrrGbp: 1450,
      billing: 'Monthly BACS Direct Debit',
      seats: '32 / 35 seats',
      seatPct: 91,
      health: 94,
      healthComment: 'Daily Webhooks Synced',
      churnRisk: 0.4,
      riskLabel: '0.4% Low',
      riskClass: 'bg-emerald-500/10 text-emerald-400',
      gateway: 'Stripe UK (BACS Direct)',
      renewal: 'Dec 01, 2026',
      apiVolume: '940,110 Total Requests',
      latency: '44ms',
      errRate: '0.004%',
      sparkline: [120, 140, 135, 160, 180, 175, 195]
    },
    {
      id: 'datawave',
      name: 'DataWave AI Labs',
      domain: 'datawave.ai',
      location: 'Austin, TX (US)',
      region: 'US',
      plan: 'GROWTH TIER',
      tierBadge: 'bg-slate-500/20 text-slate-300 border-white/10',
      initials: 'DW',
      initialsColor: 'bg-amber-500/20 text-amber-400',
      badge: 'USAGE DECAY WARNING',
      badgeColor: 'amber',
      stripeId: 'cus_ATX_7381920',
      mrrUsd: 890,
      mrrGbp: 700,
      billing: 'Monthly Visa Card',
      seats: '14 / 25 seats',
      seatPct: 56,
      health: 64,
      healthComment: 'Login Decay (-34.2% MoM)',
      churnRisk: 22.4,
      riskLabel: '22.4% WARNING',
      riskClass: 'bg-amber-500/20 text-amber-300',
      gateway: 'Stripe US (Card)',
      renewal: 'Nov 20, 2026',
      apiVolume: '320,400 Total Requests',
      latency: '62ms',
      errRate: '0.12%',
      sparkline: [210, 190, 165, 140, 110, 95, 82]
    },
    {
      id: 'apexlogic',
      name: 'Apex Retail Logic Ltd',
      domain: 'apexlogic.co.uk',
      location: 'Manchester (UK)',
      region: 'UK',
      plan: 'ENTERPRISE PRO',
      tierBadge: 'bg-violet-500/20 text-violet-300 border-violet-500/30',
      initials: 'AP',
      initialsColor: 'bg-emerald-500/20 text-emerald-400',
      badge: 'ACTIVE ENTERPRISE',
      badgeColor: 'emerald',
      stripeId: 'cus_MCR_3940192',
      mrrUsd: 3200,
      mrrGbp: 2510,
      billing: 'Annual Card Debit',
      seats: '78 / 80 seats',
      seatPct: 97,
      health: 99,
      healthComment: 'Heavy Webhooks (p99 34ms)',
      churnRisk: 0.1,
      riskLabel: '0.1% Low',
      riskClass: 'bg-emerald-500/10 text-emerald-400',
      gateway: 'Stripe UK (Mastercard)',
      renewal: 'Oct 30, 2026',
      apiVolume: '2,890,000 Total Requests',
      latency: '34ms',
      errRate: '0.001%',
      sparkline: [340, 390, 410, 430, 460, 490, 520]
    },
    {
      id: 'velomed',
      name: 'VeloMed Health LLC',
      domain: 'velomed.com',
      location: 'New York, NY (US)',
      region: 'US',
      plan: 'PAST DUE (FAILED)',
      tierBadge: 'bg-rose-500/20 text-rose-300 border-rose-500/30',
      initials: 'VM',
      initialsColor: 'bg-rose-500/20 text-rose-400',
      badge: 'PAST DUE (FAILED CHARGE)',
      badgeColor: 'rose',
      stripeId: 'cus_NYC_5501837',
      mrrUsd: 1200,
      mrrGbp: 940,
      billing: 'Monthly Card (Past Due)',
      seats: '24 / 30 seats',
      seatPct: 80,
      health: 42,
      healthComment: 'Card Expired (Visa ···· 4242)',
      churnRisk: 58.0,
      riskLabel: '58.0% CRITICAL',
      riskClass: 'bg-rose-500/20 text-rose-400',
      gateway: 'Stripe US (Declined)',
      renewal: 'Immediate Action Needed',
      apiVolume: '410,000 Total Requests',
      latency: '51ms',
      errRate: '0.08%',
      sparkline: [130, 125, 110, 90, 85, 70, 60]
    },
    {
      id: 'cambiometrics',
      name: 'Cambridge BioMetrics Ltd',
      domain: 'cambiometrics.co.uk',
      location: 'Cambridge (UK)',
      region: 'UK',
      plan: 'BUSINESS SCALE',
      tierBadge: 'bg-sky-500/20 text-sky-300 border-sky-500/30',
      initials: 'CB',
      initialsColor: 'bg-teal-500/20 text-teal-400',
      badge: 'ACTIVE SUBSCRIBER',
      badgeColor: 'emerald',
      stripeId: 'cus_CAM_9921401',
      mrrUsd: 2100,
      mrrGbp: 1650,
      billing: 'Annual Net-30 BACS',
      seats: '40 / 45 seats',
      seatPct: 89,
      health: 96,
      healthComment: 'API Cluster Active',
      churnRisk: 0.3,
      riskLabel: '0.3% Low',
      riskClass: 'bg-emerald-500/10 text-emerald-400',
      gateway: 'Stripe UK (Barclays ACH)',
      renewal: 'Jan 15, 2027',
      apiVolume: '1,120,000 Total Requests',
      latency: '39ms',
      errRate: '0.003%',
      sparkline: [190, 210, 205, 230, 250, 270, 285]
    }
  ],

  // 5. Pre-Configured AI Revenue Insights (Smart Copilot Answers)
  aiInsights: {
    'why-churn-drop': {
      question: "Why did net logo churn drop to 0.82% this quarter?",
      answer: "Net churn dropped from 2.1% to 0.82% driven by two primary factors: (1) Successful automated dunning workflows in the UK recovering 78% of failed BACS charges within 48 hours, and (2) High retention in the Enterprise Pro tier (99.2% retention), offsetting small business volatility in the US."
    },
    'arr-forecast': {
      question: "Forecast ARR growth for the next two quarters.",
      answer: "Based on trailing 90-day pipeline velocity and an average NDR of 114.2%, ARR is projected to cross $2.14M by Q1 2027 (+24.8% growth). Key expansion driver: Enterprise seat upsells across London FinTech accounts."
    },
    'expansion-tier': {
      question: "Which pricing tier yields highest Net Dollar Retention?",
      answer: "Enterprise Pro tier generates an industry-leading 118.2% NDR. Customers on this tier expand their seats by +22% within 120 days of onboarding due to API ingestion volume."
    },
    'dunning-recommendation': {
      question: "What actions are recommended for VeloMed Health?",
      answer: "VeloMed Health ($1,200/mo) is on Day 6 of card expiration. Recommendation: Send automated Grace-Period notice with a direct 1-click Stripe Customer Portal link and apply temporary API throttling on Day 10 if unresolved."
    }
  },

  // 6. Guided Tour Steps Definition
  tourSteps: [
    {
      targetId: 'overview',
      title: '1. Executive KPI Command Center',
      description: 'Real-time telemetry showing normalized MRR, Net Revenue Retention (114.2%), and Logo Churn benchmarked against top-quartile US/UK SaaS metrics.',
      position: 'bottom'
    },
    {
      targetId: 'chart-section',
      title: '2. Dynamic Revenue Trajectory',
      description: 'Interactive Chart.js curves with real-time toggle between MRR Growth, Net Churn %, and ARPU across 30-day, 90-day, and YTD trailing windows.',
      position: 'top'
    },
    {
      targetId: 'webhook-section',
      title: '3. Real-Time Stripe Webhook Stream',
      description: 'Live event ingestion log showing sub-millisecond idempotency, card charge events, and automated dispute callbacks from Stripe Billing.',
      position: 'top'
    },
    {
      targetId: 'cohort-section',
      title: '4. Cohort Retention Heatmap Matrix',
      description: 'Visual heat map tracking Month 0 through Month 6 retention rates. Switch between Logo Retention and Net Dollar Retention (NDR) in one click.',
      position: 'top'
    },
    {
      targetId: 'subscribers-section',
      title: '5. Subscriber Telemetry & CSV Export',
      description: 'Search, filter by US/UK geography or at-risk accounts, inspect deep telemetry, and download real sanitized CSV exports directly to your desktop.',
      position: 'top'
    },
    {
      targetId: 'aiCopilotSection',
      title: '6. AI Revenue Intelligence Copilot',
      description: 'Ask executive SaaS questions and receive instant data-backed answers with root-cause analysis and actionable recommendations.',
      position: 'top'
    }
  ]
};
