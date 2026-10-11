"""
Local Server for Blind Review App — PeopleGone Phase 0
Serves the blind review static interface and mounted result images.
Usage: python3 tools/blind_review/serve.py [port]
"""

import http.server
import os
import socketserver
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT_DIR, **kwargs)

    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            self.path = "/tools/blind_review/index.html"
        return super().do_GET()

def main():
    with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
        print(f"==================================================")
        print(f" PeopleGone Phase 0 Blind Review Server Running")
        print(f" URL: http://localhost:{PORT}")
        print(f" Root Directory: {ROOT_DIR}")
        print(f" Press Ctrl+C to stop the server.")
        print(f"==================================================")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server.")

if __name__ == "__main__":
    main()
