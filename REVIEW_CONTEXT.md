# 📱 PulsePath Architecture & Code Review Context

**Project:** PulsePath — Personal Activity Tracking, Daily Scoring, and Habit Analytics  
**Date:** August 26, 2026  
**Audience:** Third-Party Code Reviewers (Qwen Code Review)  
**Security Status:** 🔒 **SANITIZED ARCHIVE — Zero real secrets, API keys, credentials, or keystores included.**

---

## 1. 🏗️ Architecture Overview

PulsePath is a full-stack personal fitness and habit tracking platform designed around strict data integrity, privacy-first health integration, and grounded AI reasoning.

```text
[ Flutter 3.x Mobile Client ] ──► HTTPS / REST ──► [ FastAPI Backend (Python 3.14) ]
  ├── Riverpod 2.6 State Management                  ├── SQLAlchemy 2.0 ORM + Pydantic v2
  ├── Native Health Connect (Android)                ├── Alembic Migration Engine
  └── Secure Token & State Persistence               └── PostgreSQL 15+ Database
```

---

## 2. 🏆 Completed Phases & Milestones

1. **Phases 1–10: Authentication & Core Metrics**
   - Dual Auth: Google OAuth 2.0 & Phone/Email OTP with secure JWT access/refresh rotation.
   - Pedometer & Activity Sync: Daily steps, distance, calories, and active minutes tracking.
   - Database Model: PostgreSQL `activities` table with manual vs Health Connect provenance tracking.
2. **Phases 11–14: History, Insights & Automated Scoring**
   - Daily Score Engine (v2): Dynamic score calculation based on weighted metric progress.
   - Activity History & Trends: 7-day and 30-day aggregation endpoints with caching safeguards.
3. **Phases 15–18: VEYA AI Engine & Grounding**
   - VEYA Reasoning & Ops: Grounded AI insights engine strictly bound to verified activity evidence.
   - Integrity Safeguards: Missing ≠ Zero semantics (preventing false 0.0 metrics for unrecorded days).
4. **Phase 19: Activity Timeline & Intraday Step Trace (Batches 1–3)**
   - Database Table: `activity_step_samples` with `user_id`, `start_time`, `end_time`, `steps`, `source_origin`, and unique `sample_id` constraint.
   - Health Connect Intraday Aggregation: Native 15-minute duration-grouped aggregation engine (`getTotalStepsInInterval`).
   - Physical Validation: Verified live on Vivo Y27 (Android 15) with 4 real duration aggregate step buckets.
5. **Beta Readiness: Production Deployment Gate**
   - Production Environment Config: `APP_ENV=production`, 256-bit random JWT secret requirement, `sslmode=require` database SSL.
   - Alembic Migration Head: `100978b7787f_add_activity_step_samples_table.py`.

---

## 3. 🔒 Locked PulsePath Contracts & Invariants

> [!IMPORTANT]
> The following system contracts are strictly enforced across the codebase and must be preserved during code review and refactoring:

1. **Missing ≠ Zero Semantics:**
   - Unrecorded or missing sensor data MUST evaluate to `null` / `None` (`Not recorded`).
   - Missing data must NEVER be converted to `0.0` or fake zero.
2. **No Client-Side Metric Invention:**
   - Distance and Calories must NEVER be generated client-side from step counts using arbitrary multipliers.
   - Metrics are derived strictly from native Health Connect samples or explicit manual user logs.
3. **15-Minute Duration Bucket Boundaries:**
   - Timeline interval timestamps (`start_time`, `end_time`) represent native Health Connect aggregation window boundaries.
   - Daily step totals are NEVER split or interpolated into fake individual step timestamps.
4. **Idempotency Guarantee:**
   - Database enforces `UNIQUE(user_id, sample_id)` on `activity_step_samples`. Repeated sync taps perform in-place upserts without duplicate row accumulation.
5. **Strict Auth & Security Scoping:**
   - User isolation enforced on every SQL query (`Activity.user_id == current_user.id`).
   - Secrets must NEVER be hardcoded or exposed in API responses (`EXPOSE_PASSWORD_RESET_TOKEN = False` in production).

---

## 4. 🧪 Automated Test Suite Status

| Test Suite | Execution Command | Total Tests | Status |
| :--- | :--- | :--- | :--- |
| **FastAPI Backend Pytest Suite** | `pytest tests/` | **237 / 237** | 100% Passed |
| **Flutter Widget & Unit Suite** | `flutter test` | **146 / 146** | 100% Passed |
| **Flutter Static Analyzer** | `flutter analyze` | **0 Errors** | Clean Analysis |

---

## 5. 📂 Source Code Structure in This Review Package

```text
pulsepath_qwen_review.zip
├── REVIEW_CONTEXT.md                  <-- This architecture summary
├── pubspec.yaml                       <-- Flutter dependencies manifest
├── lib/                               <-- Flutter client source code
│   ├── core/                          <-- Theme, network, security, models
│   └── features/                      <-- Auth, Today, Journey, VEYA features
├── test/                              <-- Flutter widget & unit tests
├── android/                           <-- Android native app configuration & manifests
└── backend/                           <-- FastAPI Python backend
    ├── requirements.txt               <-- Python dependencies manifest
    ├── alembic.ini                    <-- Database migration config
    ├── .env.example                   <-- Sanitized dev environment template
    ├── .env.production.example        <-- Sanitized prod environment template
    ├── app/                           <-- API routes, DB models, schemas, services
    ├── migrations/                    <-- Alembic SQL database migrations
    └── tests/                         <-- Pytest backend test suite
```
