#!/usr/bin/env python3
"""
Local web server that mimics itch.io's hosting environment.
Provides identical CORS headers, caching behavior, and security policies.

Usage:
    just serve-web
    # or
    python3 scripts/serve_web.py [port]

Then open http://localhost:8080
"""

import os
import sys
from http import server
from functools import partial

class ItchIOHandler(server.SimpleHTTPRequestHandler):
    """HTTP handler with itch.io-identical headers."""

    def end_headers(self):
        # Itch.io security headers (required for SharedArrayBuffer/WASM threading)
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")

        # Disable caching for development iteration
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")

        # CORS headers
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

        super().end_headers()

    def guess_type(self, path):
        """Return proper MIME types for WASM files."""
        if path.endswith('.wasm'):
            return 'application/wasm'
        if path.endswith('.wasm.gz'):
            return 'application/wasm'
        if path.endswith('.data'):
            return 'application/octet-stream'
        if path.endswith('.data.gz'):
            return 'application/octet-stream'
        return super().guess_type(path)


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080

    # Serve from build-emc directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    web_build_dir = os.path.join(project_root, "build-emc")

    if not os.path.exists(web_build_dir):
        print(f"Error: Web build directory not found: {web_build_dir}")
        print("Run 'just build-web' first.")
        sys.exit(1)

    os.chdir(web_build_dir)

    handler = partial(ItchIOHandler, directory=web_build_dir)

    with server.HTTPServer(("", port), handler) as httpd:
        print(f"Serving web build at http://localhost:{port}")
        print(f"Directory: {web_build_dir}")
        print(f"Headers: itch.io-identical (COOP/COEP enabled)")
        print("Press Ctrl+C to stop")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nStopped.")


if __name__ == '__main__':
    main()
