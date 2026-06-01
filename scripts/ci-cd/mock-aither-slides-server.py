#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import threading
from urllib.parse import parse_qs, urlparse

HOST = os.environ.get("MOCK_AITHER_HOST", "127.0.0.1")
PORT = int(os.environ.get("MOCK_AITHER_PORT", "3001"))
COURSE_ID = os.environ.get("MOCK_AITHER_COURSE_ID", "course-123")
PRESENTATION_ID = os.environ.get("MOCK_AITHER_PRESENTATION_ID", "presentation-2026-06-01")

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

state = {"activeSlideIndex": 0}
state_lock = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format_, *args):
        return

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

    def do_GET(self):
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)

        if parsed.path == "/api/slides/controller":
            course_id = query.get("courseId", [""])[0]
            if course_id != COURSE_ID:
                self._send_json({"error": "course_not_found"}, status=404)
                return

            self._send_json(
                {
                    "courseId": COURSE_ID,
                    "presentationId": PRESENTATION_ID,
                    "title": "Mock Aither Deck",
                    "aspectRatio": "16:9",
                    "activeSlideIndex": state["activeSlideIndex"],
                    "lastUpdated": "2026-06-01T00:00:00Z",
                    "slides": [
                        {
                            "index": s["index"],
                            "fileName": s["fileName"],
                            "notes": s["notes"],
                            "notesSource": s["notesSource"],
                            "title": s["title"],
                        }
                        for s in SLIDES
                    ],
                }
            )
            return

        if parsed.path == "/api/slides/view":
            course_id = query.get("courseId", [""])[0]
            file_name = query.get("file", [""])[0]
            if course_id != COURSE_ID:
                self._send_json({"error": "course_not_found"}, status=404)
                return
            for slide in SLIDES:
                if slide["fileName"] == file_name:
                    self._send_html(slide["html"])
                    return
            self._send_json({"error": "slide_not_found"}, status=404)
            return

        self._send_json({"error": "not_found"}, status=404)

    def do_POST(self):
        if self.path != "/api/slides/controller/navigation":
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

        command = payload.get("command")
        if command not in ("next", "previous"):
            self._send_json({"error": "invalid_command"}, status=400)
            return

        with state_lock:
            if payload.get("fromIndex") != state["activeSlideIndex"]:
                self._send_json({"error": "out_of_sync"}, status=409)
                return

            if command == "next":
                if state["activeSlideIndex"] < len(SLIDES) - 1:
                    state["activeSlideIndex"] += 1
            elif command == "previous":
                if state["activeSlideIndex"] > 0:
                    state["activeSlideIndex"] -= 1

            active_slide_index = state["activeSlideIndex"]

        slide = SLIDES[active_slide_index]
        self._send_json(
            {
                "activeSlideIndex": active_slide_index,
                "slide": {
                    "index": slide["index"],
                    "fileName": slide["fileName"],
                    "notes": slide["notes"],
                    "notesSource": slide["notesSource"],
                    "title": slide["title"],
                },
            }
        )


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Mock Aither slides server listening on http://{HOST}:{PORT}")
    server.serve_forever()
