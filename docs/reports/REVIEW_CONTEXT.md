# 📱 PulsePath Architecture & Code Review Context (Codex / Third-Party Review)

**Project:** PulsePath — Personal Activity Tracking, Daily Scoring, and Habit Analytics  
**Date:** August 27, 2026  
**Audience:** Independent Third-Party Code Reviewers (Codex Review)  
**Live Production API URL:** [`https://pulsepath-2-yg33.onrender.com`](https://pulsepath-2-yg33.onrender.com)  
**Security Status:** 🔒 **SANITIZED ARCHIVE — Zero real secrets, API keys, credentials, or keystores included.**

---

## 1. 🏗️ Architecture Overview

PulsePath is a full-stack personal fitness and habit tracking platform designed around strict data integrity, privacy-first health integration, and grounded AI reasoning.

```text
[ Flutter 3.x Mobile Client ] ──► HTTPS (TLS 1.3) ──► [ FastAPI Backend (Render Container) ]
  ├── Riverpod 2.6 State Management                     ├── SQLAlchemy 2.0 ORM + Pydantic v2
  ├── Native Health Connect (Android 14/15)             ├── Alembic Migration Engine (Head 100978b7787f)
  └── Secure Token & State Persistence                  └── Managed PostgreSQL 15 Database (SSL)
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
   - Physical Device Validation: Verified live on Vivo Y27 (Android 15) with 4 real duration aggregate step buckets.
5. **Phase 20: Production Cloud Deployment (Render)**
   - Live HTTPS Backend: `https://pulsepath-2-yg33.onrender.com/health` returning `200 OK` (`{"status":"ok"}`).
   - Managed PostgreSQL 15 connected via SSL (`sslmode=require`).
   - Automated Alembic Migration: `100978b7787f_add_activity_step_samples_table.py` executed on container startup.
   - Gunicorn Memory Optimization: Process workers capped to 2 workers (~90MB RAM) fitting inside Render's 512MB RAM container tier.

---

## 3. 🔒 Locked PulsePath Contracts & Invariants

1. **Missing ≠ Zero Semantics:** Unrecorded sensor data evaluates to `null` (`Not recorded`), never converted to `0.0`.
2. **No Client-Side Metric Invention:** Distance and Calories derived strictly from native Health Connect samples or explicit manual user logs.
3. **15-Minute Duration Bucket Boundaries:** Intraday timeline timestamps represent native Health Connect aggregation bounds.
4. **Idempotency Guarantee:** Database enforces `UNIQUE(user_id, sample_id)` on `activity_step_samples`.
5. **Strict Auth & Security Scoping:** User isolation enforced on every SQL query (`Activity.user_id == current_user.id`).

---

## 4. 🧪 Automated Test Suite Status

| Test Suite | Execution Command | Total Tests | Status |
| :--- | :--- | :--- | :--- |
| **FastAPI Backend Pytest Suite** | `pytest tests/` | **237 / 237** | 100% Passed (21.72s) |
| **VEYA Backend Pytest Suite** | `pytest tests/test_phase17_veya_*.py` | **38 / 38** | 100% Passed |
| **Flutter Widget & Unit Suite** | `flutter test` | **146 / 146** | 100% Passed |
| **Flutter Static Analyzer** | `flutter analyze` | **0 Errors** | Clean Analysis |
| **Live Remote `/health` Smoke Test** | `curl https://pulsepath-2-yg33.onrender.com/health` | **200 OK** | `{"status":"ok"}` |
