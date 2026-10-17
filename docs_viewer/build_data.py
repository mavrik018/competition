import os
import re
import json

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PRIMARY_DOCS = [
    {
        "file": "README.md",
        "title": "Toolkit Overview",
        "category": "Core Guide",
        "badge": "Start Here",
        "icon": "book-open",
        "desc": "129 reusable Flutter components, starter template, mini-apps, and full architecture overview."
    },
    {
        "file": "QUICK_START.md",
        "title": "Quick Start Guide",
        "category": "Getting Started",
        "badge": "15 Min Setup",
        "icon": "zap",
        "desc": "Generate a competition-ready app in one command, wire screens, and integrate differentiators."
    },
    {
        "file": "COMPETITION_PLAYBOOK.md",
        "title": "Competition Playbook",
        "category": "Strategy & Execution",
        "badge": "4-5h Schedule",
        "icon": "trophy",
        "desc": "Step-by-step 4 & 5 hour schedules, problem analysis, differentiation matrix, and demo checklist."
    },
    {
        "file": "CATALOG.md",
        "title": "Component Catalog",
        "category": "Component Reference",
        "badge": "129 Components",
        "icon": "layers",
        "desc": "Comprehensive specs for all 129 components: inputs, outputs, complexity, test status, and code."
    },
    {
        "file": "ARCHITECTURE_HANDBOOK.md",
        "title": "Architecture Handbook",
        "category": "System Architecture",
        "badge": "Decision Trees",
        "icon": "compass",
        "desc": "8 decision trees, 18 decision records, layer diagrams, unidirectional data flow, and trade-offs."
    },
    {
        "file": "INTERVIEW_PREP.md",
        "title": "Interview Defense Prep",
        "category": "Technical Defense",
        "badge": "Senior Q&A",
        "icon": "message-circle",
        "desc": "Simulated senior Flutter interview with model answers, probes, failure scenarios, and risk ratings."
    },
    {
        "file": "INVENTORY_AND_PLAN.md",
        "title": "Inventory & Plan",
        "category": "Origins & Design",
        "badge": "Source Analysis",
        "icon": "clipboard-list",
        "desc": "Survey of the 4 source apps (StudyBuddies, Cookly, Couple, TaskFlow) and extraction decisions."
    },
    {
        "file": "VERIFICATION_REPORT.md",
        "title": "Verification Report",
        "category": "Testing & QA",
        "badge": "419 Passing Tests",
        "icon": "check-circle",
        "desc": "Proof of verification: automated test suite results, build status across platforms, and edge cases."
    }
]

MODULE_DOCS = [
    {
        "file": "lib/01_design_system/README.md",
        "title": "01 · Design System",
        "moduleNum": "01",
        "category": "Lib Modules",
        "badge": "Tokens & Theme",
        "icon": "palette",
        "desc": "Spacing tokens, semantic palette, typography, and complete ThemeData. System theme mode controller."
    },
    {
        "file": "lib/02_ui_elements/README.md",
        "title": "02 · UI Elements & Charts",
        "moduleNum": "02",
        "category": "Lib Modules",
        "badge": "Widgets & Charts",
        "icon": "layout",
        "desc": "Pressable, buttons, stat/action cards, RadialGauge, animations, SimpleBar/Line/Donut charts, and skeletons."
    },
    {
        "file": "lib/03_feedback/README.md",
        "title": "03 · Feedback & States",
        "moduleNum": "03",
        "category": "Lib Modules",
        "badge": "Status & Errors",
        "icon": "bell",
        "desc": "Action snackbars, Loading/Empty/ErrorView, AsyncValueView, offline & sync banners, and progress indicators."
    },
    {
        "file": "lib/04_dialogs_and_sheets/README.md",
        "title": "04 · Dialogs & Sheets",
        "moduleNum": "04",
        "category": "Lib Modules",
        "badge": "Modals & Sheets",
        "icon": "message-square",
        "desc": "iOS-styled alerts, confirm prompts, text inputs, showPickerSheet, SheetGrabber, and custom bottom sheets."
    },
    {
        "file": "lib/05_forms/README.md",
        "title": "05 · Forms & Inputs",
        "moduleNum": "05",
        "category": "Lib Modules",
        "badge": "Forms & Validation",
        "icon": "check-square",
        "desc": "Grouped form sections, segmented controls, calendar & date pickers, validators, and password checklist."
    },
    {
        "file": "lib/06_screen_templates/README.md",
        "title": "06 · Screen Templates",
        "moduleNum": "06",
        "category": "Lib Modules",
        "badge": "Full Screens",
        "icon": "smartphone",
        "desc": "OnboardingPager, AuthFormScreen, OTP, dashboard, CRUD lists, search/filter bars, and responsive grids."
    },
    {
        "file": "lib/07_navigation/README.md",
        "title": "07 · Navigation & Auth",
        "moduleNum": "07",
        "category": "Lib Modules",
        "badge": "Routing & Shell",
        "icon": "navigation",
        "desc": "TabShell, SessionGate, DeepLinkQueue, route guard, transitions, and per-user ProviderScope."
    },
    {
        "file": "lib/08_state_management/README.md",
        "title": "08 · State Management",
        "moduleNum": "08",
        "category": "Lib Modules",
        "badge": "Riverpod 3",
        "icon": "cpu",
        "desc": "ActionController, CrudController, ListQuery, PaginationController, countdowns, and debouncers."
    },
    {
        "file": "lib/09_persistence/README.md",
        "title": "09 · Persistence & Storage",
        "moduleNum": "09",
        "category": "Lib Modules",
        "badge": "SQLite & Cache",
        "icon": "database",
        "desc": "Repository<T> interface, in-memory, SQLite repository, PrefsStore, OfflineQueue, and JsonCache."
    },
    {
        "file": "lib/10_backend/README.md",
        "title": "10 · Backend & Integrations",
        "moduleNum": "10",
        "category": "Lib Modules",
        "badge": "Supabase & REST",
        "icon": "server",
        "desc": "Supabase bootstrap, AuthService, EdgeFunctionClient, ApiClient (REST), Storage, Realtime, and RevenueCat."
    },
    {
        "file": "lib/11_utilities/README.md",
        "title": "11 · Utilities & Algorithms",
        "moduleNum": "11",
        "category": "Lib Modules",
        "badge": "Pure Dart",
        "icon": "tool",
        "desc": "Spaced repetition (SM-2), streaks, date & number formatting, markdown parser, geo distances, and logger."
    },
    {
        "file": "lib/12_common_features/README.md",
        "title": "12 · Common Features",
        "moduleNum": "12",
        "category": "Lib Modules",
        "badge": "Device & Features",
        "icon": "star",
        "desc": "Reminders, permissions, Pomodoro, quiz session, file rules, media picker, QR, OCR, and export."
    },
    {
        "file": "lib/13_smart_features/README.md",
        "title": "13 · Smart Features",
        "moduleNum": "13",
        "category": "Lib Modules",
        "badge": "Deterministic AI",
        "icon": "sparkles",
        "desc": "Matching, recommendations, priority scoring, risk, trends, automation, accessibility, and CRDT sync."
    },
    {
        "file": "lib/14_ai/README.md",
        "title": "14 · AI & Fallbacks",
        "moduleNum": "14",
        "category": "Lib Modules",
        "badge": "LLM & Fallbacks",
        "icon": "bot",
        "desc": "AiTextClient with Gemini via Edge Functions, validated schema outputs, and rule-based fallbacks."
    },
    {
        "file": "example/README.md",
        "title": "Showcase & Mini-Apps",
        "moduleNum": "Demo",
        "category": "Showcase",
        "badge": "Gallery & Apps",
        "icon": "monitor",
        "desc": "28 interactive component demos and 3 fully functioning mini-apps running on fakes and in-memory data."
    }
]

def build():
    docs_list = []
    docs_content = {}
    
    all_files = PRIMARY_DOCS + MODULE_DOCS
    
    for item in all_files:
        rel_path = item["file"]
        # Normalize slashes
        clean_rel_path = rel_path.replace("\\", "/")
        full_path = os.path.join(BASE_DIR, *clean_rel_path.split("/"))
        
        if not os.path.exists(full_path):
            print(f"Skipping missing file: {full_path}")
            continue
        
        with open(full_path, "r", encoding="utf-8") as f:
            content = f.read()
            
        words = len(re.findall(r'\b\w+\b', content))
        read_time_mins = max(1, round(words / 220))
        size_kb = round(len(content.encode('utf-8')) / 1024, 1)
        
        # Check first line for title
        first_h1 = None
        for l in content.splitlines():
            if l.startswith("# "):
                first_h1 = l[2:].strip()
                break
                
        doc_entry = {
            "id": clean_rel_path,
            "filename": os.path.basename(clean_rel_path),
            "relPath": clean_rel_path,
            "title": item.get("title", first_h1 or os.path.basename(clean_rel_path)),
            "h1": first_h1 or item.get("title"),
            "category": item.get("category", "General"),
            "badge": item.get("badge", f"{size_kb} KB"),
            "icon": item.get("icon", "file-text"),
            "moduleNum": item.get("moduleNum", None),
            "desc": item.get("desc", f"Documentation for {clean_rel_path}"),
            "words": words,
            "readTime": f"{read_time_mins} min read",
            "sizeKb": size_kb,
            "isPrimary": item in PRIMARY_DOCS,
            "isModule": item in MODULE_DOCS and item.get("moduleNum") != "Demo"
        }
        docs_list.append(doc_entry)
        docs_content[clean_rel_path] = content
        
        # Also map without path for simple name lookup (e.g. "README.md")
        if item in PRIMARY_DOCS:
            docs_content[os.path.basename(clean_rel_path)] = content

    output_js_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "docs_data.js")
    with open(output_js_path, "w", encoding="utf-8") as f:
        f.write("// Auto-generated docs data for local viewer\n")
        f.write("window.DOCS_METADATA = " + json.dumps(docs_list, indent=2, ensure_ascii=False) + ";\n\n")
        f.write("window.DOCS_CONTENT = " + json.dumps(docs_content, ensure_ascii=False) + ";\n")
        
    print(f"Successfully generated {output_js_path} with {len(docs_list)} documents.")

if __name__ == "__main__":
    build()
