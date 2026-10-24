# PulseMetrics — B2B SaaS Revenue & Churn Intelligence Platform

[![Live Demo](https://img.shields.io/badge/Demo-pulsemetrics--demo.vercel.app-06b6d4?style=for-the-badge&logo=vercel&logoColor=white)](https://pulsemetrics-demo.vercel.app)
[![Architecture](https://img.shields.io/badge/Architecture-Multi--Tenant%20SaaS-8b5cf6?style=for-the-badge)](https://pulsemetrics-demo.vercel.app)
[![Security](https://img.shields.io/badge/Security-PostgreSQL%20RLS%20Isolated-10b981?style=for-the-badge&logo=postgresql&logoColor=white)](https://pulsemetrics-demo.vercel.app)
[![TypeScript / Next.js](https://img.shields.io/badge/Stack-Next.js%20%7C%20TypeScript%20%7C%20Tailwind-000000?style=for-the-badge&logo=next.js&logoColor=white)](https://pulsemetrics-demo.vercel.app)

An enterprise-grade subscription telemetry and revenue intelligence workspace designed for modern B2B SaaS companies. PulseMetrics transforms raw billing events and Stripe lifecycle webhooks into real-time operational metrics—including Net MRR, ARR run-rate, cohort retention heatmaps, customer churn velocity, and expansion revenue attribution.

---

## ⚡ Key Highlights & Production Capabilities

- **Real-Time Financial Telemetry:** Sub-second recalculation of Net New MRR, Expansion MRR, Contraction MRR, and Gross Churn.
- **Cohort Retention Matrix:** Visual cohort analysis mapping customer retention across 12-month lifecycle curves.
- **Stripe Webhook Event Pipeline:** Resilient idempotency key processing for `invoice.payment_succeeded`, `customer.subscription.updated`, and chargeback triggers.
- **Multi-Tenant Tenant Isolation:** Designed for multi-organization SaaS architecture with Row-Level Security (RLS) enforcement at the database layer.
- **Predictive Churn Scoring:** Behavioral indicators that flag high-risk accounts prior to subscription renewal dates.
- **Enterprise Dark/Light FinTech UI:** Ergonomic, high-density dashboard engineered with Tailwind CSS, Chart.js, and Lucide telemetry icons.

---

## 🏗️ System Architecture

```
                    +------------------------------------+
                    |        Stripe Webhook Rails        |
                    | (invoice.paid, sub.deleted, etc.)  |
                    +-----------------+------------------+
                                      |
                                      v
+-----------------------+     +--------------------------+
|   Client Application  | <-> |  Event Ingestion Pipeline|
|  (PulseMetrics UI)    |     |   (Idempotency & Queues) |
+-----------+-----------+     +------------+-------------+
            |                              |
            v                              v
+-----------------------+     +--------------------------+
|  Analytics Aggregator | <-> |   PostgreSQL + RLS       |
|  (MRR/ARR/Cohort Engine)    | (Tenant-Isolated Tables) |
+-----------------------+     +--------------------------+
```

### 1. Data Ingestion & Webhook Reliability
- Employs strict idempotency keys to prevent double-counting of duplicate Stripe webhook payloads.
- Background worker synchronization ensures metrics reflect real-time subscription lifecycle modifications without blocking client response times.

### 2. Multi-Tenant Data Isolation
- Enforces strict tenant separation via PostgreSQL Row-Level Security (RLS) policies.
- Every read and write transaction is bounded by `org_id` claims extracted directly from signed authentication JWTs (`auth.jwt() -> app_metadata`).
- Features a high-speed `STABLE` lookup function (`current_user_org_id()`) optimized with query-plan caching (`InitPlan`).
- Includes compound unique constraints (`org_id, idempotency_key`) to eliminate cross-tenant key enumeration risks.

---

## 📊 Modules & Functional Overview

### 1. Executive Revenue Health Deck
- **MRR Velocity:** Real-time breakdown of New, Expansion, Contraction, and Churned MRR.
- **ARR Projections:** Forward-looking annual run-rate models factoring in annualized churn rates and net retention.
- **ARPU & LTV:** Live calculation of Average Revenue Per User and Customer Lifetime Value benchmarks.

### 2. Churn Prevention & Cohort Retention
- Dynamic heatmap tracking month-over-month cohort retention down to individual customer cohorts.
- Pre-churn signals: Declining usage frequency, failed recurring billing attempts, and inactive seat licenses.

### 3. Customer Billing Ledger & Subscription Drilldown
- High-density table displaying customer-level tier, renewal cycle, MRR contribution, and status indicators.
- Instant search, status filtering (Active, Past Due, Churned), and CSV export capabilities.

---

## 🚀 Quick Start (Local Development)

### Prerequisites
- Modern web browser or local static server (Node.js 18+ recommended)

### 1. Clone the Repository
```bash
git clone https://github.com/sohailrasheedd/pulsemetrics-saas.git
cd pulsemetrics-saas
```

### 2. Run Locally
You can run this project using any local web server or directly open `index.html`:

**Using `npx serve`:**
```bash
npx serve .
```

**Using Python:**
```bash
python -m http.server 3000
```

Open `http://localhost:3000` in your browser.

---

## 📁 Repository Structure

```
pulsemetrics-saas/
├── data/
│   └── mockData.js          # Centralized financial metrics & seed data layer
├── .gitignore               # Ignored build & deployment artifacts
├── index.html               # PulseMetrics production workspace & layout
├── vercel.json              # Vercel routing & edge deployment configuration
└── README.md                # Technical architecture & operational documentation
```

---

## 👨‍💻 Engineering & Development

Built by **Sohail Rasheed** — Full-Stack & SaaS Systems Engineer.

- **Portfolio:** [sohail-rasheed.vercel.app](https://sohail-rasheed.vercel.app)
- **LinkedIn:** [linkedin.com/in/sohail-rasheedd](https://www.linkedin.com/in/sohail-rasheedd/)
- **GitHub:** [github.com/sohailrasheedd](https://github.com/sohailrasheedd)

---

## 📄 License
This project is released under the [MIT License](LICENSE).
