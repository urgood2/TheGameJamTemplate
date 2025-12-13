#!/usr/bin/env python3
"""
Local web server that mimics itch.io's hosting environment.
Serves gzipped WASM/data files with correct Content-Encoding headers.

Usage:
    just serve-web
    python3 scripts/serve_web.py [port]
"""

import os
import sys
from http import server
from functools import partial


class ItchIOHandler(server.SimpleHTTPRequestHandler):
    """HTTP handler with itch.io-identical headers and gzip support."""

    def end_headers(self):
        # COOP/COEP headers (required for SharedArrayBuffer/WASM threading)
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")

        # Disable caching for development
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")

        # CORS headers
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

        super().end_headers()

    def send_head(self):
        """Override to add Content-Encoding for .gz files."""
        path = self.translate_path(self.path)

        if path.endswith('.wasm.gz') or path.endswith('.data.gz'):
            # Serve gzipped files with Content-Encoding header
            try:
                f = open(path, 'rb')
            except OSError:
                self.send_error(404, "File not found")
                return None

            self.send_response(200)

            if path.endswith('.wasm.gz'):
                self.send_header("Content-Type", "application/wasm")
            else:
                self.send_header("Content-Type", "application/octet-stream")

            self.send_header("Content-Encoding", "gzip")
            self.send_header("Content-Length", str(os.fstat(f.fileno()).st_size))
            self.end_headers()
            return f

        return super().send_head()

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
        print(f"Headers: itch.io-identical (COOP/COEP + gzip Content-Encoding)")
        print("Press Ctrl+C to stop")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nStopped.")


if __name__ == '__main__':
    main()
