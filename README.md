# Military / Air Force Physical Readiness & Health Assessment System

## Overview
This project implements a **privacy-first, on-device physical readiness and health assessment system** designed for **military, air force, and defense personnel**.  
The system continuously analyzes **real wearable physiological data** to compute **operational readiness, fatigue, recovery, and resilience metrics**, without transmitting raw health data off the device.

The application is currently implemented as a **Flutter-based iOS app** integrated with **Apple Watch and Apple HealthKit**, alongside a **web-based dashboard** intended for future secure, derived-data visualization.


---

## Core Design Principles
- **Privacy First:** Raw physiological data never leaves the device
- **On-Device Computation:** All readiness and health scores are computed locally
- **Defense-Grade Robustness:** Robust statistics, baseline normalization, confidence metrics
- **No Medical Claims:** The system is not a medical diagnostic tool
- **Platform Compliant:** Fully aligned with iOS HealthKit security and permission models
- **Vendor-Agnostic Architecture:** Designed to support multiple wearable ecosystems

---

## Supported Devices (Current & Planned)

### Currently Implemented
- iPhone (physical device)
- Apple Watch Ultra 2
- Apple HealthKit (authoritative data broker)

### Planned
- Garmin (Connect API)
- Fitbit
- Oura Ring
- Android Health Connect
- Wear OS / Samsung Health

---

## Physiological Metrics Collected (Current: 30 Total)

### Cardiovascular
- Heart Rate
- Resting Heart Rate
- Walking Heart Rate
- Heart Rate Variability (SDNN, RMSSD)
- Blood Oxygen (SpO₂)
- Respiratory Rate
- Peripheral Perfusion Index

### Activity & Energy
- Steps
- Distance (Walking/Running, Cycling, Swimming)
- Flights Climbed
- Active Energy Burned
- Exercise Time

### Sleep
- Sleep Asleep
- Sleep Deep
- Sleep REM
- Sleep Light
- Sleep Awake
- Sleep Awake in Bed
- Sleep In Bed
- Sleep Session

### Stress & Recovery
- Electrodermal Activity (EDA)
- Mindfulness Sessions

### Heart Events
- High Heart Rate Event
- Low Heart Rate Event
- Irregular Heart Rate Event

### Body & Workout
- Body Temperature
- Workout Summaries

---

## Data Collection & Synchronization Model

### Two-Tier Synchronization Strategy
**Tier-1 (Realtime, while app is open – 60–120s):**
- Heart Rate
- Steps (optional)

**Tier-2 (Slow / Daily Metrics):**
- Sleep stages & sessions
- HRV, Resting HR
- SpO₂, Respiratory Rate
- EDA, Mindfulness
- Energy expenditure & workouts

This design prioritizes **accuracy, battery safety, and platform compliance**.

---

## Secure Storage
- All raw data is stored **locally** using **SQLCipher-encrypted SQLite**
- Encryption keys protected by OS-level secure storage
- Configurable retention policy (default ≈ 30 days for raw data)
- Long-term analytics rely only on **derived aggregates**

---

## Scoring Framework (High-Level)

All scores are:
- Individually baseline-normalized
- Robust to outliers (median, MAD, robust z-scores)
- Scaled to interpretable 0–100 ranges
- Accompanied by **confidence and data sufficiency indicators**

### Key Scores
- Overall Readiness Score
- Recovery Score
- Fatigue Index
- Sleep Quality Score
- Cardiovascular Stability
- Stress Load
- Training Load
- Injury Risk Proxy
- Resilience Index
- Operational Availability Score


Scores are computed **once sufficient data is available**, preventing misleading outputs.

---

## Privacy & Security Model
- Explicit HealthKit permission requests
- Real read attempts verify access
- User can revoke permissions at any time
- No background surveillance
- No raw health data transmitted externally
- Dashboard (future) receives derived scores only

---

## Limitations & Constraints
- Continuous background execution is restricted by iOS
- Some metrics (HRV, SpO₂, EDA) may be sparse
- Scores are updated at first valid opportunity rather than fixed times
- Accuracy is prioritized over update frequency

---

## Disclaimer
This system is **not a medical device** and does **not provide medical diagnosis or treatment recommendations**.  
It is intended for **research, operational readiness assessment, and performance monitoring** only.

---

## Contribution & Version Control
- Repository is private
- Feature development occurs on dedicated branches
- `main` branch reflects stable builds
- Code reviews required for merges

---

## Contact / Ownership
This project is part of an ongoing academic and applied research initiative focused on **6G-enabled smart systems, human performance analytics, and defense readiness monitoring**.

For access or collaboration inquiries, contact the project owner.


