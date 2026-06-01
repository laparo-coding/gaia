#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import re
from urllib.parse import parse_qs, urlparse

HOST = os.environ.get("MOCK_BRIDGE_HOST", "127.0.0.1")
PORT = int(os.environ.get("MOCK_BRIDGE_PORT", "8099"))
COURSE_ID = os.environ.get("MOCK_COURSE_ID", "course-123")
PRESENTATION_ID = os.environ.get("MOCK_PRESENTATION_ID", "presentation-2026-06-01")

SLIDES = [
    {
        "index": 0,
        "fileName": "001_intro.html",
        "notes": "Placeholder: Intro notes",
        "notesSource": "placeholder",
        "title": "Intro",
        "html": "<html><body><h1>Intro</h1></body></html>",
    },
    {
        "index": 1,
        "fileName": "002_agenda.html",
        "notes": "Placeholder: Agenda notes",
        "notesSource": "placeholder",
        "title": "Agenda",
        "html": "<html><body><h1>Agenda</h1></body></html>",
    },
    {
        "index": 2,
        "fileName": "003_topic.html",
        "notes": "Placeholder: Topic notes",
        "notesSource": "placeholder",
        "title": "Topic",
        "html": "<html><body><h1>Topic</h1></body></html>",
    },
]

state = {
    "activeSlideIndex": 0,
}


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, payload: dict, status: int = 200):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, html: str, status: int = 200):
        body = html.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format_, *args):
        return

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/controller/presentation":
            query = parse_qs(parsed.query)
            course_id = query.get("courseId", [""])[0]
            if course_id != COURSE_ID:
                self._send_json({"error": "course_not_found"}, status=404)
                return

            payload_slides = []
            for s in SLIDES:
                payload_slides.append(
                    {
                        "index": s["index"],
                        "fileName": s["fileName"],
                        "htmlURL": f"/api/controller/slides/{s['fileName']}?courseId={COURSE_ID}",
                        "notes": s["notes"],
                        "notesSource": s["notesSource"],
                        "title": s["title"],
                    }
                )

            self._send_json(
                {
                    "courseId": COURSE_ID,
                    "presentationId": PRESENTATION_ID,
                    "title": "Mock Course Day",
                    "aspectRatio": "16:9",
                    "activeSlideIndex": state["activeSlideIndex"],
                    "slideCount": len(SLIDES),
                    "slides": payload_slides,
                }
            )
            return

        match = re.match(r"^/api/controller/slides/([^/]+)$", parsed.path)
        if match:
            query = parse_qs(parsed.query)
            course_id = query.get("courseId", [""])[0]
            if course_id != COURSE_ID:
                self._send_json({"error": "course_not_found"}, status=404)
                return

            file_name = match.group(1)
            for s in SLIDES:
                if s["fileName"] == file_name:
                    self._send_html(s["html"])
                    return
            self._send_json({"error": "slide_not_found"}, status=404)
            return

        self._send_json({"error": "not_found"}, status=404)

    def do_POST(self):
        if self.path != "/api/controller/navigation":
            self._send_json({"error": "not_found"}, status=404)
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(content_length)
        try:
            payload = json.loads(raw.decode("utf-8"))
        except Exception:
            self._send_json({"error": "invalid_json"}, status=400)
            return

        if payload.get("presentationId") != PRESENTATION_ID:
            self._send_json({"error": "presentation_mismatch"}, status=409)
            return

        from_index = payload.get("fromIndex")
        command = payload.get("command")
        if from_index != state["activeSlideIndex"]:
            self._send_json({"error": "out_of_sync"}, status=409)
            return

        if command == "next":
            if state["activeSlideIndex"] < len(SLIDES) - 1:
                state["activeSlideIndex"] += 1
        elif command == "previous":
            if state["activeSlideIndex"] > 0:
                state["activeSlideIndex"] -= 1
        else:
            self._send_json({"error": "invalid_command"}, status=400)
            return

        slide = SLIDES[state["activeSlideIndex"]]
        self._send_json(
            {
                "activeSlideIndex": state["activeSlideIndex"],
                "slide": {
                    "index": slide["index"],
                    "fileName": slide["fileName"],
                    "htmlURL": f"/api/controller/slides/{slide['fileName']}?courseId={COURSE_ID}",
                    "notes": slide["notes"],
                    "notesSource": slide["notesSource"],
                    "title": slide["title"],
                },
            }
        )


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Mock controller bridge listening on http://{HOST}:{PORT}")
    server.serve_forever()
