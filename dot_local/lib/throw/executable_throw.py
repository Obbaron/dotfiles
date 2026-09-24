#!/usr/bin/env python3
"""throw: send links to the TV.

Sends shared links to a persistent mpv instance and exposes
remote-control endpoints over HTTP.
"""
import hmac
import http.cookies
import json
import logging
import math
import os
import re
import socket
import subprocess
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HYPR_ENV = os.path.expanduser("~/.local/bin/hypr-env")
HOST = os.environ.get("THROW_HOST", "0.0.0.0")
PORT = int(os.environ.get("THROW_PORT", "8080"))
TOKEN = os.environ.get("THROW_TOKEN", "")
RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
MPV_SOCKET_PATH = os.path.join(RUNTIME_DIR, "throw-mpv.sock")
# realpath: resolve the ~/.local/bin/throw symlink to the lib directory.
REMOTE_PAGE_PATH = os.path.join(
    os.path.dirname(os.path.realpath(__file__)), "remote.html"
)
COOKIE_NAME = "throw_token"
COOKIE_MAX_AGE_SECONDS = 365 * 24 * 60 * 60

# --force-window=no: the mpv window only exists while something is playing.
MPV_COMMAND = [
    HYPR_ENV,
    "mpv",
    "--idle=yes",
    "--force-window=no",
    "--fs",
    f"--input-ipc-server={MPV_SOCKET_PATH}",
]

URL_PATTERN = re.compile(r"https?://[^\s<>\"']+")
TRAILING_PUNCTUATION = ".,;:!?)]}"
FORM_CONTENT_TYPE = "application/x-www-form-urlencoded"

MPV_START_ATTEMPTS = 50
MPV_START_INTERVAL_SECONDS = 0.1
SOCKET_TIMEOUT_SECONDS = 5
REQUEST_TIMEOUT_SECONDS = 10
MAX_BODY_BYTES = 64 * 1024
REQUEST_ID = 1

# Firefox is controlled over MPRIS via playerctl. A systemd user service
# may lack the session bus address, so fall back to systemd's standard one.
PLAYERCTL_COMMAND = ["playerctl", "--player=firefox"]
PLAYERCTL_TIMEOUT_SECONDS = 2
PLAYERCTL_ENV = {
    **os.environ,
    "DBUS_SESSION_BUS_ADDRESS": os.environ.get(
        "DBUS_SESSION_BUS_ADDRESS", f"unix:path={RUNTIME_DIR}/bus"
    ),
}
FIREFOX_FIELDS = ("status", "title", "artist", "position", "mpris:length")
# ASCII unit separator: never appears in titles. Note Python treats it as
# whitespace, so playerctl output must not be .strip()ped.
FIELD_SEPARATOR = "\x1f"
# When nothing has claimed the remote yet, prefer mpv.
PLAYER_PRIORITY = ("mpv", "firefox")

logger = logging.getLogger("throw")

# Two requests arriving while mpv is down must not both launch it.
mpv_start_lock = threading.Lock()

# Auto-follow: the player that most recently started playing owns the
# remote until another one starts.
active_player_lock = threading.Lock()
last_active_player = None
previous_player_states = {}


class MpvError(Exception):
    """mpv unreachable or rejected command"""


class RequestError(Exception):
    """client sent a request we can't act on"""

    def __init__(self, message, status_code=400):
        super().__init__(message)
        self.status_code = status_code


# --- mpv IPC -----------------------------------------------------------

def connect_to_mpv():
    mpv_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    mpv_socket.settimeout(SOCKET_TIMEOUT_SECONDS)
    try:
        mpv_socket.connect(MPV_SOCKET_PATH)
    except OSError:
        mpv_socket.close()
        raise
    return mpv_socket


def start_mpv_and_connect():
    with mpv_start_lock:
        try:
            return connect_to_mpv()
        except OSError:
            pass

        logger.info("starting mpv")
        subprocess.Popen(
            MPV_COMMAND,
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        for _attempt in range(MPV_START_ATTEMPTS):
            time.sleep(MPV_START_INTERVAL_SECONDS)
            try:
                return connect_to_mpv()
            except OSError:
                pass
    raise MpvError("mpv did not start")


def send_mpv_command(*command, start_if_needed=False):
    """Run one mpv IPC command and return its data."""
    try:
        if start_if_needed:
            mpv_socket = start_mpv_and_connect()
        else:
            mpv_socket = connect_to_mpv()
    except OSError:
        raise MpvError("nothing is playing") from None

    request = {"command": list(command), "request_id": REQUEST_ID}
    try:
        with mpv_socket:
            mpv_socket.sendall(json.dumps(request).encode() + b"\n")
            return read_mpv_response(mpv_socket)
    except OSError as error:  # includes socket timeouts
        raise MpvError(f"lost connection to mpv: {error}") from error


def read_mpv_response(mpv_socket):
    buffer = b""
    while True:
        chunk = mpv_socket.recv(65536)
        if not chunk:
            raise MpvError("mpv closed the connection")
        buffer += chunk
        while b"\n" in buffer:
            line, buffer = buffer.split(b"\n", 1)
            try:
                message = json.loads(line)
            except json.JSONDecodeError as error:
                raise MpvError("mpv sent invalid JSON") from error
            # mpv interleaves event messages; skip anything but our reply.
            if message.get("request_id") != REQUEST_ID:
                continue
            if message.get("error") != "success":
                raise MpvError(message.get("error"))
            return message.get("data")


def get_mpv_property(name):
    try:
        return send_mpv_command("get_property", name)
    except MpvError:
        return None


# --- Firefox (MPRIS) ---------------------------------------------------

def run_playerctl(*args):
    """Run playerctl against Firefox; return its output, or None."""
    try:
        result = subprocess.run(
            [*PLAYERCTL_COMMAND, *args],
            capture_output=True,
            text=True,
            timeout=PLAYERCTL_TIMEOUT_SECONDS,
            env=PLAYERCTL_ENV,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    return result.stdout.rstrip("\n")


def microseconds_to_seconds(text):
    try:
        seconds = float(text) / 1_000_000
    except ValueError:
        return None
    return seconds if seconds > 0 else None


def get_firefox_info():
    """Firefox's current media, or None if it has none."""
    template = FIELD_SEPARATOR.join("{{" + f + "}}" for f in FIREFOX_FIELDS)
    output = run_playerctl("metadata", "--format", template)
    if output is None:
        return None
    fields = output.split(FIELD_SEPARATOR)
    if len(fields) != len(FIREFOX_FIELDS):
        return None
    status, title, artist, position, length = fields
    if status not in ("Playing", "Paused"):
        return None
    return {
        "state": "playing" if status == "Playing" else "paused",
        "title": title,
        "artist": artist,
        "position": microseconds_to_seconds(position) or 0,
        "duration": microseconds_to_seconds(length),
    }


def firefox_command(*args):
    if run_playerctl(*args) is None:
        raise RequestError("Firefox didn't respond", status_code=502)


# --- choosing the player -----------------------------------------------

def get_mpv_state():
    """"playing", "paused", or None when mpv has nothing loaded."""
    if get_mpv_property("idle-active") is not False:
        return None
    return "paused" if get_mpv_property("pause") else "playing"


def mark_active(player):
    global last_active_player
    with active_player_lock:
        last_active_player = player


def choose_player(states):
    """Pick the player the remote should control, given each one's state."""
    global last_active_player
    with active_player_lock:
        for name, state in states.items():
            was_playing = previous_player_states.get(name) == "playing"
            if state == "playing" and not was_playing:
                last_active_player = name
        previous_player_states.clear()
        previous_player_states.update(states)

        if last_active_player and states.get(last_active_player):
            return last_active_player
        for wanted_state in ("playing", "paused"):
            for name in PLAYER_PRIORITY:
                if states.get(name) == wanted_state:
                    return name
        return None


def find_active_player():
    """Return (player name or None, Firefox info or None)."""
    firefox = get_firefox_info()
    states = {
        "mpv": get_mpv_state(),
        "firefox": firefox["state"] if firefox else None,
    }
    return choose_player(states), firefox


def require_active_player():
    player, _firefox = find_active_player()
    if player is None:
        raise RequestError("nothing is playing", status_code=409)
    return player


# --- playback actions --------------------------------------------------

def is_playing():
    return get_mpv_property("idle-active") is False


def play_now(url):
    if is_playing():
        # Slot the link in next and skip to it, keeping the queue.
        send_mpv_command("loadfile", url, "insert-next")
        send_mpv_command("playlist-next", "force")
    else:
        send_mpv_command("loadfile", url, "replace", start_if_needed=True)
    # Pause carries over between files; a freshly shared link should play.
    send_mpv_command("set_property", "pause", False)
    mark_active("mpv")
    return "playing"


def add_to_queue(url):
    was_playing = is_playing()
    send_mpv_command("loadfile", url, "append-play", start_if_needed=True)
    if not was_playing:
        send_mpv_command("set_property", "pause", False)
        mark_active("mpv")
        return "playing"
    send_mpv_command("show-text", "Added to queue", 2000)
    return "queued"


def get_status():
    player, firefox = find_active_player()
    if player == "firefox":
        return {
            "player": "firefox",
            "media-title": firefox["title"],
            "artist": firefox["artist"],
            "pause": firefox["state"] == "paused",
            "time-pos": firefox["position"],
            "duration": firefox["duration"],
            "can-volume": False,
            "can-queue": False,
        }
    if player == "mpv":
        status = {"player": "mpv", "can-volume": True, "can-queue": True}
        property_names = (
            "media-title",
            "pause",
            "time-pos",
            "duration",
            "volume",
            "playlist-pos",
            "playlist-count",
        )
        for name in property_names:
            status[name] = get_mpv_property(name)
        return status
    return {"player": None}


def parse_number(params, key, default):
    raw_value = params.get(key, default)
    try:
        number = float(raw_value)
    except ValueError:
        raise RequestError(f"{key} must be a number, got {raw_value!r}")
    if not math.isfinite(number):
        raise RequestError(f"{key} must be finite, got {raw_value!r}")
    return number


def toggle_pause(params):
    if require_active_player() == "firefox":
        firefox_command("play-pause")
    else:
        send_mpv_command("cycle", "pause")


def next_item(params):
    if require_active_player() == "firefox":
        firefox_command("next")
    else:
        send_mpv_command("playlist-next", "force")


def previous_item(params):
    if require_active_player() == "firefox":
        firefox_command("previous")
    else:
        send_mpv_command("playlist-prev", "force")


def stop(params):
    """Stop mpv and clear its queue (mpv only)."""
    send_mpv_command("stop")


def seek(params):
    """?t=+30 / ?t=-10 seeks relatively; ?to=90 jumps to 1:30."""
    player = require_active_player()
    if "to" in params:
        seconds = parse_number(params, "to", "0")
        if player == "firefox":
            firefox_command("position", f"{seconds:g}")
        else:
            send_mpv_command("seek", seconds, "absolute")
        return

    offset = parse_number(params, "t", "10")
    if player == "firefox":
        direction = "+" if offset >= 0 else "-"
        firefox_command("position", f"{abs(offset):g}{direction}")
    else:
        send_mpv_command("seek", offset, "relative")


def change_volume(params):
    """?v=+5 or ?v=-5 is relative; ?v=60 sets an absolute level (mpv only)."""
    volume = parse_number(params, "v", "+5")
    if params.get("v", "+5").startswith(("+", "-")):
        send_mpv_command("add", "volume", volume)
    else:
        send_mpv_command("set_property", "volume", volume)


CONTROL_ACTIONS = {
    "/pause": toggle_pause,
    "/next": next_item,
    "/prev": previous_item,
    "/stop": stop,
    "/seek": seek,
    "/volume": change_volume,
}


# --- HTTP --------------------------------------------------------------

def parse_query(query):
    # Keep a literal "+" (normally decoded as a space) so ?v=+5 works.
    query = query.replace("+", "%2B")
    return {
        key: values[0]
        for key, values in urllib.parse.parse_qs(query).items()
    }


def token_matches(supplied):
    # compare_digest takes constant time, so timing leaks nothing.
    return hmac.compare_digest(supplied.encode(), TOKEN.encode())


def make_token_cookie(token):
    return (
        f"{COOKIE_NAME}={token}; Path=/; Max-Age={COOKIE_MAX_AGE_SECONDS}; "
        "HttpOnly; SameSite=Strict"
    )


def extract_url(text):
    """Pull the first URL out of text like 'Look! https://youtu.be/...'."""
    match = URL_PATTERN.search(text or "")
    if match is None:
        return None
    return match.group(0).rstrip(TRAILING_PUNCTUATION)


class ThrowRequestHandler(BaseHTTPRequestHandler):
    # Drop clients that connect and then stall.
    timeout = REQUEST_TIMEOUT_SECONDS

    def do_GET(self):
        self.handle_request(has_body=False)

    def do_POST(self):
        self.handle_request(has_body=True)

    def handle_request(self, has_body):
        try:
            parsed_url = urllib.parse.urlparse(self.path)
            params = parse_query(parsed_url.query)
            body = ""
            if has_body:
                body = self.read_body()
                if self.headers.get_content_type() == FORM_CONTENT_TYPE:
                    params.update(parse_query(body))
            path = parsed_url.path.rstrip("/") or "/"
            if self.is_remote_page_request(path, params, has_body):
                self.serve_remote_page(params)
                return
            self.check_token(params)
            self.route(path, params, body)
        except RequestError as error:
            self.reply(error.status_code, str(error))
        except MpvError as error:
            self.reply(502, str(error))

    def read_body(self):
        try:
            content_length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            raise RequestError("invalid Content-Length") from None
        if content_length < 0:
            raise RequestError("invalid Content-Length")
        if content_length > MAX_BODY_BYTES:
            raise RequestError("body too large", status_code=413)
        return self.rfile.read(content_length).decode("utf-8", "replace")

    def check_token(self, params):
        if not TOKEN:
            return
        candidates = (
            self.headers.get("X-Throw-Token"),
            params.get("token"),
            self.cookie_token(),
        )
        if not any(token and token_matches(token) for token in candidates):
            raise RequestError("invalid or missing token", status_code=403)

    def cookie_token(self):
        cookies = http.cookies.SimpleCookie()
        try:
            cookies.load(self.headers.get("Cookie", ""))
        except http.cookies.CookieError:
            return None
        morsel = cookies.get(COOKIE_NAME)
        return morsel.value if morsel else None

    def wants_html(self):
        """Browsers navigating to a page ask for HTML; scripts don't."""
        return "text/html" in self.headers.get("Accept", "")

    def is_remote_page_request(self, path, params, has_body):
        bare_root = path == "/" and not has_body and "url" not in params
        return path == "/remote" or bare_root

    def serve_remote_page(self, params):
        # The page itself holds no secrets, so it's served without a
        # token. A ?token= here signs this browser in, then drops the
        # token from the address bar.
        token = params.get("token")
        if token and TOKEN and token_matches(token):
            self.redirect("/remote", set_token_cookie=token)
            return
        try:
            with open(REMOTE_PAGE_PATH, encoding="utf-8") as page:
                html = page.read()
        except OSError:
            raise RequestError(f"missing {REMOTE_PAGE_PATH}", status_code=500)
        self.reply(200, html, "text/html")

    def redirect(self, location, set_token_cookie=None):
        self.send_response(303)
        self.send_header("Location", location)
        self.send_header("Referrer-Policy", "no-referrer")
        if set_token_cookie:
            self.send_header("Set-Cookie", make_token_cookie(set_token_cookie))
        self.send_header("Content-Length", "0")
        self.end_headers()

    def route(self, path, params, body):
        if path == "/status":
            self.reply(200, json.dumps(get_status()), "application/json")
        elif path in CONTROL_ACTIONS:
            CONTROL_ACTIONS[path](params)
            self.reply(200, "ok")
        else:
            self.handle_link(path, params, body)

    def handle_link(self, path, params, body):
        url = (
            extract_url(params.get("url"))
            or extract_url(body)
            or extract_url(" ".join(params.values()))
        )
        if url is None:
            raise RequestError("no URL found")
        if path == "/open":
            subprocess.Popen(
                [HYPR_ENV, "xdg-open", url], start_new_session=True
            )
            result = "opened in browser"
        elif path == "/queue":
            result = add_to_queue(url)
        else:
            # /play, or any other path (matches the old behaviour).
            result = play_now(url)

        if not self.wants_html():
            self.reply(200, result)
            return
        # A browser tab (e.g. from AddToAny): show the remote instead.
        location = "/remote?" + urllib.parse.urlencode({"msg": result})
        token = params.get("token")
        remember = token if token and TOKEN and token_matches(token) else None
        self.redirect(location, set_token_cookie=remember)

    def reply(self, status_code, text, content_type="text/plain"):
        payload = (text.rstrip("\n") + "\n").encode()
        self.send_response(status_code)
        self.send_header("Content-Type", f"{content_type}; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_request(self, code="-", size="-"):
        # Log the path only: the query string may carry the token.
        path = urllib.parse.urlparse(self.path).path
        status = getattr(code, "value", code)
        logger.info(
            "%s %s %s %s", self.address_string(), self.command, path, status
        )

    def log_message(self, format_string, *args):
        logger.warning("%s %s", self.address_string(), format_string % args)


def main():
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    if not TOKEN:
        logger.warning("THROW_TOKEN is not set; anyone on the network "
                       "can control playback")
    server = ThreadingHTTPServer((HOST, PORT), ThrowRequestHandler)
    logger.info("listening on %s:%d", HOST, PORT)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
