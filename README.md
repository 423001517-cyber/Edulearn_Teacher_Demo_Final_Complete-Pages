# EduLearn

**EduLearn: A Mobile Interactive Learning Application on Araling Panlipunan for Grade 4, 5, and 6 in Philippine Cultural College**

EduLearn is a hybrid role-based learning platform (mobile app + web portal) that helps Grade 4–6 Chinese-national students at Philippine Cultural College overcome language barriers in learning Araling Panlipunan through gamified quests, real-time translation support, and automated progress reporting.

**Team:** Compas, Mark Lester J. · Gañola, Shierrellane Mae M. · Magallanes, Jean L. · Rey, Quinjoa D. · Siguen, Jeremie Brandon R.

> **New here? Open [`START_HERE.md`](START_HERE.md)** — how to run everything on your computer.

---

## Apps in this repository (Flutter + Firebase)

One repository for every EduLearn app, sharing one Firebase project:

| App | Folder | Status |
|---|---|---|
| Teacher website | `apps/teacher_web` | ✅ Homepage (Dashboard) + Classes built |
| Admin website | `apps/admin_web` | ✅ Dashboard, Teachers, Classes & codes, Class Requests, Students, School Reports, Settings |
| Student app (Android/iOS) | `apps/student_app` | 🔜 waiting for designs |

Shared code lives in `packages/` so all three apps use the same data models, colors and widgets.

---

## Admin website (`apps/admin_web`)

Built in the same EduLearn style as the teacher website (no admin mockups yet — send them and the screens will be matched).

| Page | URL | What the admin does there |
|---|---|---|
| Dashboard | `/` | School at a glance: teachers, students, active classes, pending requests; classes overview, performance by grade, classes needing attention |
| Teachers | `/teachers` | Add a teacher (creates their sign-in + a set-password link), view their classes, send a new password link, disable/enable |
| Classes | `/classes?teacher=` | Create a class → an official code is issued (e.g. `RIZAL-4A`); edit, reassign to another teacher, issue a new code, archive/restore |
| Class Requests | `/requests` | Approve a teacher's "Request New Class" (adjustable) or decline with a reason — the teacher is notified either way |
| Students | `/students?classId=` | Class rosters: add, edit, move between classes, remove, import from CSV |
| Reports | `/reports?period=` | Every class compared (completion, score, attendance, missing work, change vs last period), school trend, PDF/CSV export |
| Settings | `/settings` | School name and school year; add/remove administrators |

**Who is an admin?** A user whose Firebase Auth token has the custom claim `role: "admin"`. Only trusted server code sets it: the `setAdminRole` function, `tools/admin/make_admin.mjs` (first admin) or `tools/seed` (demo). The login screen checks it and anyone else sees "This account isn't an administrator".

**How the admin connects to the teacher website:**
- A class the admin creates or approves appears on that teacher's Dashboard and Classes page right away, and the teacher gets a notification with the class code.
- Students added or imported by the admin appear in the teacher's class rosters, and the class's student count updates on its own.
- **Reassigning** a class moves all of its students, classwork, submissions, attendance and reports to the new teacher (the `onClassReassigned` function).
- A teacher's **Request New Class** (Classes page) lands in the admin's Class Requests.

---

## Teacher website

A responsive teacher website (Flutter web first; Android and iOS work too) built from the EduLearn mockups.

**Built so far:** Dashboard (homepage), Classes, the Open Class page with its tabs, the filtered Students page, Class Reports with the four detail panels (Completion, Average Score, Attendance, Missing Work), and the **Stream** page with Class settings. The remaining sidebar sections (Classwork, Calendar, Submissions, Gradebook, Analytics, Attendance, Rewards, Messages, Settings) already have URLs and show a placeholder page, so links to them work today and each one can be built next.

### Stream (`/stream?classId=`)

| Part | What it does |
|---|---|
| Class banner | Cover, class name, subject, students and code. **Copy code**, and ⋮ → Class settings · Edit class details · Archive class |
| Upcoming | Graded work due soon; **View all →** opens the class's Classwork tab |
| Composer | Pick the class (or all classes); **B / I / U / list / link** formatting; **File / Link / Video** attachments (up to 10, 25 MB each); **Post ▾** → Post now · Schedule (date + time) · Save draft. A short first line becomes the bold headline |
| Posts | Announcements, plus automatic posts for published classwork ("Teacher Jean posted an assignment / a quiz / a material") with Due and points chips and **View assignment / View quiz** |
| All posts filter | Announcements · Assignments · Quizzes · Materials · Scheduled · Drafts |
| Class comments | Side panel per post with Reply · Copy link · Delete comment, file attachments, and a Teacher badge |
| Class settings (`/stream/settings`) | Subject, room, class code (Copy / **Reset code**), stream permissions, classwork notifications, total points, show overall grade |

Class name and section are official (set by the admin), so they appear read-only in Class settings and Edit class details. Scheduled posts go live on time through the `publishScheduledPosts` function. On the local demo, scheduled functions don't run, so the website also shows a scheduled post as live once its time has passed. The class page's **Stream** tab uses the same feed.

| Layer | Choice |
|---|---|
| UI | Flutter 3.32+ (Material 3, Plus Jakarta Sans), responsive: phone drawer · tablet icon rail · desktop sidebar |
| State | Riverpod 2 (live Firestore streams) |
| Navigation | go_router 17 — real URLs such as `/classes/rizal-4a?tab=classwork` |
| Auth | Firebase Authentication (email/password + Google) |
| Data | Cloud Firestore (security rules + composite indexes included) |
| Files | Cloud Storage (lesson uploads, class covers, generated PDF/CSV reports) |
| Backend | Cloud Functions v2 (TypeScript, `asia-southeast1`, schedules in Asia/Manila) |
| Hosting | Firebase Hosting (`build/web`) |

---

## 1. Quick start

**New here? Read `START_HERE.md` first.** You don't copy code anywhere: every file is already in place. Just run the numbered scripts in the root folder (`.bat` on Windows, `.sh` on Mac/Linux):

| Script | What it does |
|---|---|
| `1-setup` | Run once. Installs the Firebase CLI, Flutter packages, Cloud Functions and the demo-data tool, then adds the platform folders (`add-platform-folders`). |
| `2-start-firebase` | Runs Firebase on your computer (the emulators). Keep it open. Stop it with Ctrl+C to save the data. |
| `3-load-demo-data` | Loads the demo classes, students, teachers and admin. |
| `4-run-teacher-website` | Teacher website in Chrome at http://localhost:5050 |
| `5-run-admin-website` | Admin website in Chrome at http://localhost:5100 |

| Website | Sign in with |
|---|---|
| Teacher | **jean@edulearn.test / edulearn123** |
| Admin | **admin@edulearn.test / edulearn123** |

Prerequisites: Flutter 3.32+, Node.js 22, **Java 21 (JDK)** for the Firebase emulators, and Chrome.

**Demo mode:** both apps ship with demo Firebase settings (project `demo-edulearn` in `firebase_options.dart` and `.firebaserc`). A `demo-…` project runs entirely on the local emulators, so there's no Firebase account, billing or `flutterfire configure` step until you go live. Web folders (`apps/*/web/`) are included, and `1-setup` adds the Android, iOS and desktop folders for you. The emulator dashboard is at http://127.0.0.1:4000.

In VS Code, open the `edulearn` folder and pick **Teacher website**, **Admin website** or **Both websites** under Run and Debug. Keep step 2 running.

The seed data matches the mockups:
- 68 active students across Grade 4 – Rizal (RIZAL-4A), Grade 5 – Bonifacio (BONI-5B) and Grade 6 – Mabini (MABI-6C), plus 1 archived class.
- 7 students with missing work, 14 submissions to review, and 9 active quests this week.
- Rizal's report shows 75% (+12%), 82% (+8%), 94% (+4%) and 2 missing (−6), with Difficult Topics at about 68–71%.
- 3 teachers (one disabled), 2 pending class requests, and school settings for the admin site.
- The Grade 4 – Rizal stream: "Welcome to Quarter 1!" with 5 class comments, an assignment, a quiz and a reading material (due next week, so the dashboard numbers above don't change), one scheduled post and one draft.

To check the numbers without Firebase, run `node seed.mjs --dry-run` in `tools/seed`.

**Checks:** `flutter analyze` at the root; `flutter test` in `packages/edulearn_core`, `apps/teacher_web` and `apps/admin_web`; `npm test` in `firebase/functions`.

### Going live with a real Firebase project

1. Create a project in the Firebase console. In it:
   - **Authentication → Sign-in method:** enable Email/Password and Google.
   - **Firestore:** create the database (`asia-southeast1` is close to the Philippines).
   - **Storage:** create the default bucket.
2. Put your project id in `.firebaserc` in place of `demo-edulearn`.
3. In **each** app folder (`apps/teacher_web` and `apps/admin_web`), run:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure        # same project for both; replaces lib/firebase_options.dart
   ```
   With a real project id, the apps talk to the real Firebase automatically. Add `--dart-define=USE_EMULATORS=true` to keep testing on the emulators.
4. Deploy rules, indexes, functions and both websites:
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes,storage
   ```
5. The platform folders come from `add-platform-folders` (part of `1-setup`). For Android builds with Firebase, set `minSdk = 23` in `android/app/build.gradle.kts` if Gradle asks. For real Android/iOS keys, `flutterfire configure` also registers those platforms.

### Deploy for real

```bash
(cd firebase/functions && npm install)
firebase deploy --only functions      # needs the Blaze (pay-as-you-go) plan
(cd apps/teacher_web && flutter build web --release)
(cd apps/admin_web && flutter build web --release)

# one time: create the admin site and link both sites to the targets in firebase.json
firebase hosting:sites:create <your-admin-site-id>
firebase target:apply hosting teacher <your-project-id>        # the default site
firebase target:apply hosting admin <your-admin-site-id>

firebase deploy --only hosting            # or hosting:teacher / hosting:admin
```

Custom domains (e.g. `teacher.edulearn.ph`, `admin.edulearn.ph`) are added per site in the Firebase console.

**The first real administrator:** the person signs up once (for example on the teacher website), then you run:

```bash
cd tools/admin && npm install
gcloud auth application-default login
node make_admin.mjs --project <your-project-id> --email principal@school.edu.ph
```

They sign out and back in, and can then open the admin website. After that, admins add each other in **Settings → Administrators**.

To put demo data in a real staging project, use Application Default Credentials: `node seed.mjs --project <id> --reset`.

---

## 2. Folder structure

```
edulearn/
├── START_HERE.md                 read me first — how to run everything
├── 1-setup … 5-run-admin-website numbered scripts (.bat Windows, .sh Mac/Linux)
├── add-platform-folders          runs `flutter create .` in both apps → android, ios, windows,
│                                 macos, linux folders for YOUR Flutter version (code is kept)
├── .vscode/launch.json           Run buttons: Teacher website · Admin website · Both
├── pubspec.yaml                  workspace root — lists every app and package
├── analysis_options.yaml         lint rules shared by all Dart code
├── firebase.json · .firebaserc   ONE Firebase project for all apps
│
├── apps/
│   ├── admin_web/                ✅ the admin website
│   │   ├── pubspec.yaml
│   │   ├── web/                  index.html, manifest, icons
│   │   ├── android/ ios/ windows/ macos/ linux/   added by 1-setup (flutter create)
│   │   ├── test/                 admin_test.dart · widget_test.dart
│   │   └── lib/
│   │       ├── main.dart · firebase_options.dart
│   │       ├── app/              app.dart · router.dart (role-guarded URLs) · routes.dart
│   │       ├── data/             admin_session (role check) · admin_repository · admin_functions
│   │       ├── providers/        core_providers · admin_providers
│   │       └── features/
│   │           ├── auth/         login · not-authorized
│   │           ├── shell/        admin sidebar (+ pending-requests badge) · top bar
│   │           ├── dashboard/    admin homepage
│   │           ├── teachers/     teachers page · add teacher · teacher drawer
│   │           ├── classes/      classes page · create/edit/reassign · new code · archive
│   │           ├── requests/     approve / decline class requests
│   │           ├── students/     rosters · add/edit/move · CSV import (roster_csv.dart)
│   │           ├── reports/      school reports + export
│   │           ├── settings/     school profile · administrators
│   │           └── common/       admin table, pickers, code chip, action helpers
│   │
│   └── teacher_web/              ✅ the teacher website
│       ├── pubspec.yaml
│       ├── web/                  index.html, manifest, icons
│       ├── android/ ios/ windows/ macos/ linux/   added by 1-setup (flutter create)
│       ├── test/                 routes_test.dart · widget_test.dart
│       └── lib/
│           ├── main.dart                 Firebase init, emulator switch, clean URLs
│           ├── firebase_options.dart     demo settings now; `flutterfire configure` replaces it when you go live
│           ├── app/                      app.dart · router.dart (every URL) · routes.dart
│           ├── core/                     navigation.dart (toast, goTo)
│           ├── data/                     teacher-only Firestore access (filtered by teacherId)
│           │   auth · dashboard · classes · reports · storage repositories
│           ├── providers/                Riverpod state
│           │   core · data (shared live streams) · dashboard · classes · reports
│           └── features/
│               ├── auth/                 login_screen
│               ├── shell/                sidebar · top bar (bell, profile) · placeholders
│               ├── dashboard/            ① HOMEPAGE — dashboard_page + widgets/
│               ├── classes/              ② CLASSES — classes_page · class_detail_page
│               │   ├── tabs/             overview · stream · classwork · gradebook · analytics
│               │   └── widgets/          class_card · class_actions (⋮) · quick_view_panel · class_dialogs
│               ├── students/             students_page · students_table · student_support_panel
│               ├── reports/              reports_page · report_actions · widgets/ · panels/
│               ├── classwork/            quick create · classwork form · details popover · reuse
│               ├── announcements/        form + tile (dashboard card)
│               ├── stream/               ③ STREAM — stream_page · class_banner · upcoming_card ·
│               │                         stream_feed · stream_composer · post_cards ·
│               │                         comments_panel · class_settings_page · stream_widgets
│               └── submissions/          review popover
│
├── packages/                     shared by teacher, admin and student apps
│   ├── edulearn_core/            no UI: data models + logic (incl. ClassRequest,
│   │                                 SchoolSettings, AdminUser for the admin site)
│   │   ├── lib/edulearn_core.dart        import this one file
│   │   ├── lib/src/models/               ClassRoom, Student, ClassworkItem, Submission, …
│   │   ├── lib/src/dates.dart            Manila-aware dates, "2 hours ago"
│   │   ├── lib/src/reports/              report_math · report_exporter (PDF/CSV)
│   │   └── test/core_test.dart
│   └── edulearn_ui/              look & feel
│       ├── lib/edulearn_ui.dart          import this one file
│       ├── lib/src/theme.dart            EduLearn colors, fonts, breakpoints
│       └── lib/src/widgets/              cards, pills, StatCard, charts, dialogs, side panels,
│                                         page_scaffold (page layout used by both websites)
│
├── firebase/                     backend for all apps
│   ├── firestore.rules · firestore.indexes.json · storage.rules
│   └── functions/src/            TypeScript Cloud Functions
│       ├── triggers · reminders · scheduled · rollup     teacher-side automation
│       └── admin/                callables (create class + code, requests, accounts,
│                                 roles) · codes.ts (code rules) · propagate.ts (reassign)
│
└── tools/
    ├── seed/                     demo data matching the mockups (+ admin sign-in)
    └── admin/                    make_admin.mjs — make the first real administrator
```

**How the layers fit together:**
- A **page** in `features/` reads **providers**; providers call the app's **data** repositories; repositories talk to **Firebase**.
- **Models, dates and report math** come from `edulearn_core`. **Colors and widgets** come from `edulearn_ui`.
- A shared package never imports an app, and `edulearn_core` never imports `edulearn_ui`.

**Adding the student app later:**
1. Create `apps/student_app` (same inner layout: `app/`, `data/`, `providers/`, `features/`).
2. Add it to the root `pubspec.yaml` workspace list.
3. Depend on `edulearn_core` and `edulearn_ui`.

---

## 3. How the homepage and Classes are connected

| From | Action | Goes to |
|---|---|---|
| Sidebar | Dashboard / Classes / Students / Reports | `/`, `/classes`, `/students`, `/reports` |
| Dashboard · My Classes | **View all classes** | `/classes` |
| Dashboard · My Classes | **Open Class** (or tap the row) | `/classes/:classId` |
| Dashboard · Upcoming popover | **Open Classwork** | `/classes/:classId?tab=classwork` |
| Dashboard · Students Needing Support ⋮ | **Open class** | `/classes/:classId?tab=students` |
| Dashboard · Missing Work card (a class selected) | tap | `/reports?classId=…&panel=missing` |
| Classes · card | **Open Class** / **Quick View** / ⋮ | class page / drawer / actions menu |
| Classes · ⋮ | **View Students** · **View Reports** | `/students?classId=…` · `/reports?classId=…` |
| Class page · **Create Classwork** | same Quick Create dialog as the homepage | class preselected |
| Class page · stat cards | Completion / Class Average / Missing Work | the matching Reports panel |
| Class page · breadcrumb | **← Classes** | `/classes` |

Beyond links, both pages read the **same live streams** (`apps/teacher_web/lib/providers/data_providers.dart`). So:
- **Archiving** a class on the Classes page removes it from the homepage right away (My Classes, class selector, stats). If the homepage class selector was set to that class, it resets to "All Classes".
- **Returning** a submission, **posting** an announcement, or **creating** a quest from either page updates both.
- The Classes page **filters** are kept alive, so going Classes → a class → back keeps your search, grade and sort.

---

## 4. Data model (Firestore)

Every teacher-owned document has `teacherId`; all client queries filter by it, and the rules enforce it.

| Collection | Written by | Used for |
|---|---|---|
| `teachers/{uid}` (+ `notifications/`) | app (profile), functions (notifications) | greeting, bell |
| `classes/{id}` (+ `dailyPerformance/{yyyy-MM-dd}`, `monthlyStats/{yyyy-MM}`) | **administrator** (grade, section, code); teacher may change `status`, `subject`, `coverImageUrl`, `room`, `description`, `streamPermission`, `classworkNotifications`, `totalPoints`, `showOverallGrade`; functions keep counters | cards, charts, reports, Class settings |
| `students/{id}` | administrator / functions (progress fields) | tables, support flags |
| `classwork/{id}` (+ `comments/`) | teacher; functions own `submittedCount`, `scoreSum`, `scoredCount`, `commentCount` | quests, quizzes, lessons, Friday Boss; stream posts |
| `submissions/{id}` | student app; teacher grades (`score`, `privateFeedback`, `status`, `returnedAt`) | To Review, averages |
| `announcements/{id}` (+ `comments/`) | teacher (`classId: null` = all classes); `status` published · scheduled (`publishAt`) · draft; `attachments`; functions own `commentCount` | Stream, homepage |
| `activity/{id}` | functions | "Recent Class Activity" |
| `missingWork/{studentId_classworkId}` | functions | Missing Work panel |
| `attendance/{classId_yyyy-MM-dd}` | teacher / attendance module (`marks: {studentId: present\|late\|absent}`) | Attendance panel |
| `reminders/{id}` | teacher → delivered by FCM function | Send Reminder |
| `classRequests/{id}` | teacher creates; admin approves/declines via functions | "+ Request New Class" |
| `classCodes/{code}` | functions | keeps official class codes unique (`{classId}`) |
| `admins/{uid}` | `setAdminRole` function | admin profiles (the role itself is an Auth custom claim) |
| `settings/school` | admin | school name, school year, contact email |

Storage paths:
- `lessons/{uid}/…`: lesson files, up to 25 MB.
- `class-covers/{uid}/…`: class cover images, up to 5 MB.
- `reports/{uid}/…`: generated PDF and CSV reports.
- `stream/{uid}/…`: post and class comment attachments, up to 25 MB.

Consider a lifecycle rule that deletes old `reports/` files after, say, 30 days.

---

## 5. Cloud Functions

| Function | Trigger | What it does |
|---|---|---|
| `onSubmissionWritten` | submission create/update/delete | classwork counters; removes the missing-work row; "Maria submitted a quiz"; "5 new submissions" notification |
| `onClassworkWritten` | classwork write | class `questCount`; "New quiz published: …" |
| `onStudentWritten` | student create/move | class `studentCount`; "… joined the class" |
| `onAnnouncementCreated` | announcement create | "You posted an announcement" in each class feed |
| `deliverReminder` | reminder create | FCM push to the student's devices; prunes dead tokens |
| `publishScheduledClasswork` | hourly | scheduled items (Friday Boss) go live on their date |
| `nightlyRollup` | 9:00 PM Manila | student progress, missing work, class completion/average, chart point, monthly report row, "missed"/"completed" feed, teacher notifications |
| `publishScheduledPosts` | every 5 minutes | scheduled stream posts go live at `publishAt` |
| `onAnnouncementComment` · `onClassworkComment` | class comment create/delete | `commentCount` on the post; notifies the teacher when a student comments |
| `createClass` · `approveClassRequest` · `declineClassRequest` · `regenerateClassCode` | admin (callable); `regenerateClassCode` also for the class's own teacher (Reset code) | classes with unique official codes; the teacher is notified |
| `createTeacherAccount` · `teacherPasswordLink` · `setTeacherStatus` · `setAdminRole` | admin (callable) | sign-in accounts, password links, disable/enable, admin role |
| `onClassReassigned` | class `teacherId` changes | moves the class's students, classwork, submissions, attendance and reports to the new teacher |

The rollup math lives in `firebase/functions/src/rollup.ts` (no Firebase) and is unit-tested: `cd firebase/functions && npm test`.

Seeded documents carry `seed: true`, so the triggers don't double-count them.

---

## 6. Notes

- **Classes and class codes are official.** Neither website writes classes directly. They're created by the `createClass` / `approveClassRequest` functions, which reserve a unique code, and the rules block direct creation.
- **The student app is a separate project.** It creates `submissions` and saves `fcmTokens` on the student document.
- **Exports.** PDF and CSV reports are built on the device, uploaded to Storage, and opened from a link (on the web, the "Open" button on the toast avoids popup blockers). The built-in PDF font covers Latin-1, which includes ñ.
- **Time zone.** Report and chart documents are keyed by Manila date (`2026-09`, `2026-09-26`), so they read correctly on any device time zone.
- **Next modules.** Each remaining sidebar section only needs a page in `apps/teacher_web/lib/features/<name>/` and one route change in `app/router.dart`. The links already pass `?classId=`.
- **Roles.** `admin` and `teacher` custom claims are in place (`firebase/firestore.rules` has an `isAdmin()` check). For the student app, add a `student` role, student read rules, and a `joinClass` function that looks up `classCodes/{code}`. `onSubmissionWritten` already handles submissions from the student app.
