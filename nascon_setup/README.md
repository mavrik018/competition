# NaSCon '26 — environment setup (booklet §2–§3)

Status of this laptop on 2026-10-15, and how teammates repeat it. Everything marked ✅ was run and checked here.

## 1. Docker image bundle (booklet §2)

```bash
powershell -ExecutionPolicy Bypass -File nascon_setup\pull_images.ps1
```

| Image | Status |
|---|---|
| postgres:16-alpine · redis:7-alpine · rabbitmq:3.13-management-alpine · nats:2.10-alpine | ✅ pulled |
| bluenviron/mediamtx:1.9.1 · livekit/livekit-server:v1.7.2 · binwiederhier/ntfy:v2.11.0 | ✅ pulled |
| prom/prometheus:v2.54.1 · grafana/grafana:11.2.0 · grafana/k6:0.54.0 | ✅ pulled |
| selenium/hub · node-chrome · node-firefox · node-edge (all 4.24.0) | ✅ pulled (Edge = Intel/AMD Windows variant) |
| python:3.12-slim · node:20-alpine | ✅ both pulled (booklet asks for one) |
| **minio/minio:RELEASE.2024-09-22T00-33-43Z** | ❌ **cannot be pulled by anyone**: the `minio/minio` repository no longer exists on Docker Hub (API returns 404) and `quay.io/minio/minio` returns 401. The cloud autograder cannot pull it either. Ask the organisers whether it is a decoy or which replacement image to use before relying on object storage. |

About 9.5 GB of images in total. Docker Desktop must be running (`docker info` works) before pulling or composing.

## 2. Mobile platform (booklet §2.1.1)

| Item | Status |
|---|---|
| Flutter + Android SDK (platform 37, build-tools 36) | ✅ present; APK builds verified |
| Pub cache: every toolkit package | ✅ cached (a full `create_app` + `pub get` ran) |
| Gradle cache for those plugins | ✅ cached (a full-toolkit `flutter build apk --debug` ran) |
| `ANDROID_HOME` and `adb` on PATH | ✅ set for this Windows user (open a new terminal to pick it up) |
| Android SDK licences | ⚠️ **you** must accept: `flutter doctor --android-licenses` (accepting terms is your decision) |
| Physical phone | ⚠️ enable Developer options → USB debugging; bring the cable; check `adb devices` lists it |

## 3. Automated testing tools (booklet §2.1.2)

| Tool | Version | Status |
|---|---|---|
| Appium | 2.19.0 (`npm i -g appium@2`) | ✅ |
| UiAutomator2 driver | 4.2.9 — the newest driver (5.x) requires Appium 3, so it is pinned: `appium driver install uiautomator2@4.2.9` | ✅ `appium driver doctor uiautomator2`: 0 required fixes |
| Selenium WebDriver (Python) | 4.51.0 | ✅ |
| pytest + pytest-html + allure-pytest | pytest 9.1.1 | ✅ |
| Allure CLI | 2.46.1 (`npm i -g allure-commandline`, uses the installed JDK) | ✅ |
| Appium Python client | latest | ✅ |
| k6 | `grafana/k6:0.54.0` Docker image | ✅ |
| Locust | 2.46.7 | ✅ |

Teammates: `python -m pip install selenium pytest pytest-html allure-pytest Appium-Python-Client locust requests`.

## 4. End-to-end smoke test (proves the pieces work together)

`docker-compose.smoke.yml` runs Postgres, Redis, a Selenium hub and a Chrome node with the booklet's low-RAM settings (`shm_size: "1gb"`, `SE_START_VNC: "false"`).

```bash
docker compose -f nascon_setup/docker-compose.smoke.yml up -d --wait
```
```bash
python -m pytest nascon_setup/test_smoke.py --html=nascon_setup/report.html --self-contained-html
```
```bash
docker run --rm --network nascon_smoke_default -v "%cd%/nascon_setup:/scripts" grafana/k6:0.54.0 run /scripts/k6_smoke.js
```
```bash
docker compose -f nascon_setup/docker-compose.smoke.yml down
```

Result here: all 4 containers healthy · pytest **2 passed** (remote Chrome rendered a page) with an HTML report · k6 **5,759 requests, 0 failed, p95 10 ms**.

## 5. Things only you can do

* Accept the Android licences (above).
* Before Saturday: create a **private** GitHub repo under the team lead's account and invite `nascon-eval-26`. Keep it **completely empty** (zero commits) until 10:45 on Day 1.
* Bring a phone hotspot or travel router (campus Wi-Fi isolates devices).
* Start Docker Desktop before leaving home and check `docker images` lists the bundle.

## 6. What the booklet changes about our plan

* **Supabase and Firebase are prohibited** (managed BaaS). Do not use the toolkit's `10_backend` Supabase files or the `ai-complete` Edge Function. The backend must be your own service in `docker-compose.yml` (e.g. `python:3.12-slim` or `node:20-alpine` + `postgres:16-alpine` + `redis:7-alpine`). The Flutter side still fits: `ApiClient` (REST) behind the `Repository<T>` seam.
* **Two sprints, not one 4-hour block:** Day 1 10:45–15:00 (4 h 15 min, autograded, then locked) and Day 2 10:15–14:00 (3 h 45 min, new problem part, continues from the Day 1 commit).
* **Graded in the cloud** from `docker-compose.yml` on GitHub Actions (`ubuntu-latest`, 16 GB). Only pushed commits count; push at least hourly (−2 points per missed hour).
* **Viva (top 8):** live code mutation, two hidden complexity scenarios, `ADR.md` (8 short decision records) and `TRACEABILITY.md` (requirements → code → tests).
* **Tie-breaker:** number of automated test vectors passed — tests are worth writing.
