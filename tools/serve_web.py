"""Serve the exported Godot web build (build/web) on the preview port.

Export first:  godot --headless --path . --export-release "Web" build/web/index.html
Then:          python3 tools/serve_web.py            # http://localhost:3001
               PORT=8080 python3 tools/serve_web.py  # other port
"""
import functools
import http.server
import os
import socketserver

ROOT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", "web")
PORT = int(os.environ.get("PORT", "3001"))


class Handler(http.server.SimpleHTTPRequestHandler):
    # The engine streams its build as WebAssembly and its data as a pack.
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "text/javascript",
    }

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *args):
        pass


if not os.path.isdir(ROOT):
    raise SystemExit("No web build at %s - export it first (see the docstring)." % ROOT)

print("Serving %s on http://0.0.0.0:%d" % (ROOT, PORT), flush=True)
socketserver.ThreadingTCPServer.allow_reuse_address = True
with socketserver.ThreadingTCPServer(
        ("0.0.0.0", PORT), functools.partial(Handler, directory=ROOT)) as server:
    server.serve_forever()
