# Campus Portal

Android campus management system with Django REST API backend and Flutter mobile app.

**Full technical documentation:** [docs/TECHNICAL_DOCUMENTATION.md](docs/TECHNICAL_DOCUMENTATION.md)

## Feature Audit & Roadmap

## Objective alignment

| Goal | Status | Notes |
|------|--------|-------|
| Android campus management system | **Achieved** | Flutter app with auth, content, support |
| Student ↔ admin communication | **Achieved** | Support tickets with staff replies in-app + notifications |
| Streamline academic operations | **Partial** | Notes, assignments, groups, grades, attendance |
| Learning resource accessibility | **Achieved** | Notes, e-library with download |
| Graphical admin insights | **Achieved** | Chart.js dashboard at `/admin/` |
| Student registration & login | **Achieved** | JWT + register API |
| Role-based access | **Achieved** | Student / lecturer / staff permissions |

## Innovative ideas checklist

| Idea | Status |
|------|--------|
| Graphical reporting dashboard | ✅ Admin Chart.js (students, courses, support, notes, grades) |
| Smart notifications | ⚠️ In-app announcements only; push/SMS not yet integrated |
| E-Library + offline | ✅ Download books to device; notes/assignments downloadable |
| Support desk chatbot | ✅ Rule-based Campus Assistant (FAQ) |
| Cross-platform sync | ✅ Shared REST API; admin web + mobile app |
| Secure authentication | ✅ JWT, refresh tokens, role permissions |

## Mobile app features

- Login / register (username or email)
- Home dashboard with stats & announcements
- Course notes (read PDF/TXT, download)
- Assignments (view, download; lecturers upload)
- Study groups
- E-Library (browse, download offline)
- Performance / grades
- Attendance history & rate
- Support tickets (submit, track status, **read staff replies**)
- Profile + photo upload
- Campus Assistant (FAQ chatbot)

## Recommended next steps

1. **Firebase Cloud Messaging** — push alerts for announcements & assignment deadlines
2. **SMS gateway** (Twilio) — urgent alerts for low attendance
3. **Assignment submissions** — students upload work; lecturers grade
4. **LLM chatbot** — replace rule-based assistant with API-backed AI
5. **PostgreSQL** — migrate from SQLite for production
6. **Offline sync layer** — Hive/SQLite cache for lists when offline

## Test accounts

Run `python manage.py create_sample_data` then use:

- Student: `student001` / `password123`
- Lecturer: `lecturer1` / `lecturer123`
- Admin: `admin` / `admin123` → `/admin/`

## Run locally

```bash
# Backend
cd backend
python manage.py runserver 0.0.0.0:8000

# Flutter (Android emulator)
cd frontend/campus_app
flutter run
```
