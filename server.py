#!/usr/bin/env python3
"""
Local Documentation Server for Flutter Competition Toolkit
Serves the docs viewer and automatically opens your default browser.
"""

import os
import sys
import webbrowser
import http.server
import socketserver
from pathlib import Path

# Fix Windows console UTF-8 output if possible
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

CURRENT_DIR = Path(__file__).resolve().parent
DOCS_VIEWER_DIR = CURRENT_DIR / "docs_viewer"
BUILD_DATA_SCRIPT = DOCS_VIEWER_DIR / "build_data.py"

if BUILD_DATA_SCRIPT.exists():
    try:
        import subprocess
        subprocess.run([sys.executable, str(BUILD_DATA_SCRIPT)], check=True, cwd=str(CURRENT_DIR))
    except Exception as e:
        print(f"Warning: Could not rebuild docs_data.js: {e}")

PORT = 5050
MAX_PORT = 5065

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(CURRENT_DIR), **kwargs)

    def do_GET(self):
        # Redirect root / to /docs_viewer/
        if self.path == '/' or self.path == '':
            self.send_response(302)
            self.send_header('Location', '/docs_viewer/')
            self.end_headers()
            return
        return super().do_GET()

    def log_message(self, format, *args):
        # Suppress noisy asset requests from console output
        return

def start_server():
    global PORT
    server = None
    while PORT <= MAX_PORT:
        try:
            socketserver.TCPServer.allow_reuse_address = True
            server = socketserver.TCPServer(("127.0.0.1", PORT), CustomHandler)
            break
        except OSError:
            PORT += 1

    if not server:
        print(f"Error: Could not bind to any port between 5050 and {MAX_PORT}.")
        sys.exit(1)

    url = f"http://127.0.0.1:{PORT}/docs_viewer/"
    print("=" * 65)
    print("  Flutter Competition Toolkit - Local Documentation Hub")
    print("=" * 65)
    print(f"  Local Web Viewer URL: {url}")
    print(f"  Serving directory:    {CURRENT_DIR}")
    print("  Status: Server is active and ready.")
    print("  To stop: Press Ctrl+C in this terminal.")
    print("=" * 65)

    # Open browser automatically
    try:
        webbrowser.open(url)
    except Exception:
        pass

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server. Goodbye!")
        server.server_close()

if __name__ == "__main__":
    start_server()
