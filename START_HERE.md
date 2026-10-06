# START HERE — EduLearn

**You don't need to copy or move any code.** Every file is already in the right place inside this `edulearn` folder. The `01_…`, `02_…` and `03_…code.md` documents are only for reading.

This folder contains two complete Flutter websites that share the same code and data:

- **Teacher website:** `apps/teacher_web`
- **Admin website:** `apps/admin_web`

---

## A. Install these once

| Program | Where to get it | Check it works (in a terminal) |
|---|---|---|
| Flutter 3.32 or newer | https://docs.flutter.dev/get-started/install | `flutter --version` |
| Node.js 22 (LTS) | https://nodejs.org | `node --version` |
| Java 21 (JDK) | https://adoptium.net (Temurin 21) | `java -version` |
| Google Chrome | https://www.google.com/chrome | |
| VS Code + Flutter extension (optional) | https://code.visualstudio.com | |

Java is only used by the Firebase emulators, which run Firebase on your own computer. Firebase needs **version 21 or newer**.

## B. Unzip

Unzip `edulearn.zip` somewhere simple, for example `C:\projects\edulearn`. Avoid folders with spaces or OneDrive folders if you can.

## C. Run it (in order)

On **Windows**, double-click the `.bat` files. On **Mac/Linux**, run the `.sh` files in Terminal (for example `./1-setup.sh`).

| # | File | When | What you'll see |
|---|---|---|---|
| 1 | `1-setup` | First time only | Downloads packages and adds the `android`, `ios`, `windows`, `macos` and `linux` folders. It takes a few minutes and ends with "Setup finished". |
| 2 | `2-start-firebase` | Every time | Firebase starts on your computer. **Keep this window open.** When it says "All emulators ready", continue. |
| 3 | `3-load-demo-data` | First time (or to reset) | Loads the demo classes, students, teachers and admin. |
| 4 | `4-run-teacher-website` | Whenever | Chrome opens the teacher website (http://localhost:5050). |
| 5 | `5-run-admin-website` | Whenever | Chrome opens the admin website (http://localhost:5100). |

> **Already ran `1-setup` before this version?** Double-click `add-platform-folders` once. It adds the `android`, `ios`, `windows`, `macos` and `linux` folders without touching your code.

**Sign in with:**
- Teacher website: `jean@edulearn.test` / `edulearn123`
- Admin website: `admin@edulearn.test` / `edulearn123`

When you're done, click the Firebase window and press **Ctrl+C**. That saves the demo data, so next time you only need steps 2, 4 and 5.

Firebase's own dashboard, where you can see the data, is at http://127.0.0.1:4000.

### Using VS Code instead of steps 4–5

Open the `edulearn` folder in VS Code (**File → Open Folder**). Go to **Run and Debug** and pick **Teacher website**, **Admin website** or **Both websites**, then press ▶. Step 2 must still be running.

---

## D. Where things are

```
edulearn/
├── apps/
│   ├── teacher_web/       ← the teacher website: a normal Flutter project
│   │   ├── lib/           ← its code (homepage, classes, reports…)
│   │   ├── web/ test/ pubspec.yaml
│   │   └── android/ ios/ windows/ macos/ linux/   ← added by 1-setup
│   └── admin_web/         ← the admin website (same layout)
│       └── lib/           ← its code (teachers, classes & codes, requests…)
├── packages/
│   ├── edulearn_core/     ← data models and logic shared by both websites
│   └── edulearn_ui/       ← colors, fonts and widgets shared by both websites
├── firebase/              ← security rules + Cloud Functions (the "backend")
└── tools/seed/            ← the demo data
```

Each app folder looks like a project made with `flutter create`. `build/` appears after the first run, and `.dart_tool/` appears after setup; both are made automatically. The two apps sit inside `apps/` so they can share `packages/`.

To change a screen, open its file under `apps/…/lib/features/`. For example:
- `apps/teacher_web/lib/features/dashboard/`: the teacher homepage
- `apps/admin_web/lib/features/classes/`: the admin Classes page

While a website is running, press **r** in its window (or save in VS Code) to see changes instantly.

---

## E. If something goes wrong

| Message | Fix |
|---|---|
| `Deploy target teacher not configured` | You have an old `2-start-firebase` — use the new zip (it starts only auth, firestore, functions and storage). |
| `Port 8080 is not open` / `port taken` | An old Firebase window is still running. Close every black Firebase/Java window (or end `java.exe` in Task Manager) and start again. |
| `WARNING: sun.misc.Unsafe …` lines | Harmless notices from newer Java versions — ignore them. |
| `firebase-tools no longer supports Java version before 21` | Install Java 21 from adoptium.net, close the window, and run step 2 again. |
| `'flutter' / 'node' / 'firebase' is not recognized` | Close all windows and open them again after installing. If it still fails, restart your computer so the new programs are on PATH. |
| Sign-in says the email or password is wrong | Run step 3 (demo data) while step 2 is running. |
| Page stays loading, or errors about `127.0.0.1:8080` / `connection refused` | Step 2 isn't running. Start it and wait for "All emulators ready". |
| `Failed to bind web development server … errno = 10048 … port = 5050` | The website is already running in another window (or a leftover background copy). The run scripts now pick the next free port automatically (5051, 5052…). To free 5050 again, close the other EduLearn website windows, or restart your computer. |
| Firebase: `Failed to load function definition … Timeout after 10000` | Windows took longer than 10 seconds to load the Cloud Functions the first time. `2-start-firebase` now waits up to 60 seconds; close the Firebase window (Ctrl+C) and start it again. |
| Firebase: `requested "node" version "22" doesn't match your global version "24"` | Harmless — it runs with your Node 24. Installing Node 22 LTS removes the message. |
| Android build: `minSdkVersion … cannot be smaller than 23` | Open `apps/<app>/android/app/build.gradle.kts` and set `minSdk = 23` (Firebase needs it). |
| Anything else | Copy the red error text and send it to me. |

---

## F. Going live later (real Firebase project)

Right now everything runs on your computer with a demo project called `demo-edulearn`. It's free and needs no Firebase account. When you're ready to publish, follow **"Going live with a real Firebase project"** in `README.md`. The main steps are: create a Firebase project, run `flutterfire configure` in each app folder, then deploy.
