#!/usr/bin/env python3
"""throw: send links to the TV.

Plays YouTube links in a dedicated Firefox window on the HTPC (the "TV
window"), keeps a queue for it, and exposes remote-control endpoints over
HTTP. throw drives the window from outside: Hyprland focuses it, wtype
types into it, and Firefox's MPRIS interface reports what's playing.
"""
import hmac
import http.cookies
import json
import logging
import math
import os
import queue
import re
import shutil
import subprocess
import threading
import time
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HYPR_ENV = os.path.expanduser("~/.local/bin/hypr-env")
HOST = os.environ.get("THROW_HOST", "0.0.0.0")
PORT = int(os.environ.get("THROW_PORT", "8080"))
TOKEN = os.environ.get("THROW_TOKEN", "")
RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
# realpath: resolve the ~/.local/bin/throw symlink to the lib directory.
REMOTE_PAGE_PATH = os.path.join(
    os.path.dirname(os.path.realpath(__file__)), "remote.html"
)
COOKIE_NAME = "throw_token"
COOKIE_MAX_AGE_SECONDS = 365 * 24 * 60 * 60

URL_PATTERN = re.compile(r"https?://[^\s<>\"']+")
TRAILING_PUNCTUATION = ".,;:!?)]}"
FORM_CONTENT_TYPE = "application/x-www-form-urlencoded"
YOUTUBE_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{11}$")
YOUTUBE_PATH_PATTERN = re.compile(r"^/(?:shorts|live|embed)/([^/]+)")
HYPRLAND_ADDRESS_PATTERN = re.compile(r"^0x[0-9a-fA-F]+$")

REQUEST_TIMEOUT_SECONDS = 10
MAX_BODY_BYTES = 64 * 1024
TOOL_TIMEOUT_SECONDS = 5

# How long to wait for things to happen on the TV.
# After a cold boot, throw can be answering before Hyprland has started:
# wait up to this long for the session before acting on a link.
SESSION_WAIT_SECONDS = 60
WINDOW_APPEAR_SECONDS = 20
WINDOW_SETTLE_SECONDS = 1.5  # let session-restored windows appear too
FOCUS_SETTLE_SECONDS = 0.2
# Leaving YouTube's fullscreen animates; Firefox ignores Ctrl+L until done.
FULLSCREEN_EXIT_MS = 800
# Time for the address bar to take focus before typing starts.
ADDRESS_BAR_MS = 250
PLAYBACK_START_SECONDS = 20
# YouTube's player needs a moment after playback starts before "f" works.
FULLSCREEN_DELAY_SECONDS = 1.5
FULLSCREEN_ATTEMPTS = 3
# How long to watch for the window to go fullscreen after pressing "f".
FULLSCREEN_CONFIRM_SECONDS = 2
# After a navigation, the TV isn't judged idle or finished for this long.
# At least PLAYBACK_START_SECONDS, so a slow-starting link isn't adopted as
# something new before throw has recognised it.
LOAD_GRACE_SECONDS = 20
WATCH_INTERVAL_SECONDS = 1
# Paused within this many seconds of the end counts as finished.
END_TOLERANCE_SECONDS = 1.5
HISTORY_LIMIT = 50
# YouTube reports its position and length to Firefox only for a moment
# after a seek, so throw keeps its own clock. A short seek backwards makes
# YouTube report, once per video; afterwards, give the report a moment.
TIMING_NUDGE = "0.1-"
SEEK_REPORT_SECONDS = 0.6
# Titles for the remote's queue list come from YouTube's public oEmbed
# service (what sites use for link previews); thumbnails from its images.
OEMBED_URL = "https://www.youtube.com/oembed?format=json&url="
THUMBNAIL_URL = "https://i.ytimg.com/vi/{}/mqdefault.jpg"
LOOKUP_TIMEOUT_SECONDS = 5
# Firefox windows that can't be the TV (they share Firefox's window class).
NOT_TV_WINDOW_TITLES = ("Picture-in-Picture",)

# Firefox media is watched and controlled over MPRIS via playerctl. A
# systemd user service may lack the session bus address, so fall back to
# systemd's standard one.
PLAYERCTL_COMMAND = ["playerctl", "--player=firefox"]
TOOL_ENV = {
    **os.environ,
    "DBUS_SESSION_BUS_ADDRESS": os.environ.get(
        "DBUS_SESSION_BUS_ADDRESS", f"unix:path={RUNTIME_DIR}/bus"
    ),
}
FIREFOX_FIELDS = ("status", "title", "artist", "position", "mpris:length")
# ASCII unit separator: never appears in titles. Note Python treats it as
# whitespace, so playerctl output must not be .strip()ped.
FIELD_SEPARATOR = "\x1f"
VOLUME_TARGET = "@DEFAULT_AUDIO_SINK@"
QUIET_PATHS = ("/status",)  # polled constantly by the remote
# Only these accept links. Anything else is rejected, so a stray client
# posting a URL to some other path can't start playback.
LINK_PATHS = ("/", "/play", "/queue", "/open")

logger = logging.getLogger("throw")


class RequestError(Exception):
    """client sent a request we can't act on"""

    def __init__(self, message, status_code=400):
        super().__init__(message)
        self.status_code = status_code


class ToolError(Exception):
    """an external tool (hyprctl, wtype, ...) failed"""


# --- running tools -----------------------------------------------------

def run_tool(args, timeout=TOOL_TIMEOUT_SECONDS):
    """Run a command and return its stdout; raise ToolError on failure."""
    try:
        result = subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=TOOL_ENV,
        )
    except FileNotFoundError:
        raise ToolError(f"{args[0]} is not installed") from None
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ToolError(f"{args[0]} failed: {error}") from error
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise ToolError(f"{args[0]} failed: {detail}")
    return result.stdout


def in_session(*args):
    """Run a command inside the Hyprland session via hypr-env."""
    return run_tool([HYPR_ENV, *args])


# --- Hyprland ----------------------------------------------------------

def hypr_clients():
    return json.loads(in_session("hyprctl", "clients", "-j"))


def wait_for_session():
    """Block until Hyprland answers, or give up after SESSION_WAIT_SECONDS."""
    deadline = time.monotonic() + SESSION_WAIT_SECONDS
    waited = False
    while True:
        try:
            hypr_clients()
        except (ToolError, ValueError):
            if time.monotonic() > deadline:
                raise ToolError("the Hyprland session isn't running")
            if not waited:
                logger.info("waiting for the Hyprland session to start")
                waited = True
            time.sleep(1)
            continue
        if waited:
            logger.info("Hyprland session is up")
        return


def hypr_client(address):
    for client in hypr_clients():
        if client.get("address") == address:
            return client
    return None


def active_window():
    return json.loads(in_session("hyprctl", "activewindow", "-j")).get(
        "address"
    )


def focus_window(address):
    if not HYPRLAND_ADDRESS_PATTERN.match(address or ""):
        raise ToolError(f"not a window address: {address!r}")
    # A Lua config reads dispatch arguments as Lua; a classic hyprlang
    # config needs focuswindow. Try the Lua form first.
    lua = f'hl.dsp.focus({{ window = "address:{address}" }})'
    try:
        if in_session("hyprctl", "dispatch", lua).strip() == "ok":
            return
    except ToolError:
        pass
    in_session("hyprctl", "dispatch", "focuswindow", f"address:{address}")


# One keyboard: key sequences must never interleave.
keyboard_lock = threading.Lock()


def send_keys(window, *wtype_args):
    """Focus window, type into it with wtype, then give focus back."""
    with keyboard_lock:
        previous = active_window()
        if previous != window:
            focus_window(window)
            time.sleep(FOCUS_SETTLE_SECONDS)
            # Never type unless the TV window really has focus.
            if active_window() != window:
                raise ToolError("couldn't focus the TV window")
        in_session("wtype", *wtype_args)
        if previous and previous != window:
            focus_window(previous)


# --- Firefox media (MPRIS) and volume ----------------------------------

def run_playerctl(*args):
    """Run playerctl against Firefox; return its output, or None."""
    try:
        output = run_tool([*PLAYERCTL_COMMAND, *args])
    except ToolError:
        return None
    return output.rstrip("\n")


def microseconds_to_seconds(text):
    try:
        seconds = float(text) / 1_000_000
    except ValueError:
        return None
    return seconds if seconds > 0 else None


def get_firefox_media():
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


def pause_all_playback():
    """Pause whatever is playing: another Firefox tab, Spotify, ..."""
    try:
        statuses = run_tool(["playerctl", "--all-players", "status"])
    except ToolError:
        return  # no players at all
    if "Playing" not in statuses.split():
        return
    logger.info("pausing what was already playing")
    try:
        run_tool(["playerctl", "--all-players", "pause"])
    except ToolError as error:
        logger.warning("couldn't pause existing playback: %s", error)


def get_volume():
    """The system volume as a percentage, or None if unavailable."""
    try:
        output = run_tool(["wpctl", "get-volume", VOLUME_TARGET])
    except ToolError:
        return None
    match = re.search(r"Volume:\s*([0-9.]+)", output)
    return round(float(match.group(1)) * 100) if match else None


def set_volume(amount, relative):
    if relative:
        direction = "+" if amount >= 0 else "-"
        level = f"{abs(amount):g}%{direction}"
    else:
        level = f"{min(100, max(0, amount)):g}%"
    try:
        run_tool(["wpctl", "set-volume", "-l", "1.0", VOLUME_TARGET, level])
    except ToolError as error:
        raise RequestError(str(error), status_code=502) from None


# --- YouTube links -----------------------------------------------------

def youtube_watch_url(url):
    """The canonical watch URL for a single YouTube video, or None.

    Playlist parameters are dropped: YouTube would move through the
    playlist by itself, behind the queue's back.
    """
    parsed = urllib.parse.urlparse(url)
    host = (parsed.hostname or "").removeprefix("www.").removeprefix("m.")
    params = urllib.parse.parse_qs(parsed.query)

    video_id = None
    if host == "youtu.be":
        video_id = parsed.path.lstrip("/").split("/")[0]
    elif host == "youtube.com":
        if parsed.path == "/watch":
            video_id = params.get("v", [""])[0]
        else:
            match = YOUTUBE_PATH_PATTERN.match(parsed.path)
            video_id = match.group(1) if match else None
    if not video_id or not YOUTUBE_ID_PATTERN.match(video_id):
        return None

    query = {"v": video_id}
    if "t" in params:
        query["t"] = params["t"][0]
    return "https://www.youtube.com/watch?" + urllib.parse.urlencode(query)


def video_id_of(url):
    """The video ID in a canonical watch URL, or None."""
    params = urllib.parse.parse_qs(urllib.parse.urlparse(url or "").query)
    return params.get("v", [None])[0]


def fetch_video_info(url):
    """A YouTube video's title and channel, or None if unavailable."""
    lookup = OEMBED_URL + urllib.parse.quote(url, safe="")
    try:
        with urllib.request.urlopen(
            lookup, timeout=LOOKUP_TIMEOUT_SECONDS
        ) as response:
            data = json.load(response)
    except (OSError, ValueError):
        return None
    return {
        "title": str(data.get("title") or ""),
        "channel": str(data.get("author_name") or ""),
    }


def open_in_new_window(url):
    """Open a link in a new Firefox window on the HTPC's screen."""
    subprocess.Popen(
        [HYPR_ENV, "firefox", "--new-window", url],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


# --- the TV window -----------------------------------------------------

# Stands in for "current" when the TV is showing something throw didn't
# start: a video opened by hand, a recommendation clicked on the TV, or one
# playing before throw restarted. Whatever plays on the HTPC is on the TV,
# so throw adopts it and the remote and queue carry on around it.
ADOPTED = "(already playing)"


class TvController:
    """The TV window, its queue, and the threads that drive it.

    A worker thread carries out navigations one at a time (they involve
    focusing and typing), and a watcher thread polls Firefox's media state
    to feed the remote and to notice when a video finishes.
    """

    def __init__(self):
        self.lock = threading.RLock()
        self.jobs = queue.Queue()
        self.window = None        # Hyprland address of the TV window
        self.history = []
        self.current = None       # the URL the TV should be showing
        self.queue = []
        self.tv_title = None      # media title of the video on the TV
        self.title_before = None  # media title when we last navigated
        self.navigated_at = None
        self.finished = None      # the URL whose end already moved us on
        self.media = None         # latest Firefox media state
        self.volume = None
        self.clock = self._new_clock(None)
        self.video_info = {}      # URL -> title and channel, for the queue

    def start(self):
        threading.Thread(target=self._work, daemon=True).start()
        threading.Thread(target=self._watch, daemon=True).start()

    # Internal helpers: call these with self.lock held.

    def _is_tv(self, media):
        if not media or not self.tv_title:
            return False
        return media["title"] == self.tv_title

    def _loading(self):
        if self.navigated_at is None:
            return False
        return time.monotonic() - self.navigated_at < LOAD_GRACE_SECONDS

    def _at_end(self, media):
        duration = media.get("duration")
        return bool(
            media["state"] == "paused"
            and duration
            and media["position"] >= duration - END_TOLERANCE_SECONDS
        )

    def _set_current(self, url):
        if self.current and self.current != ADOPTED:
            self.history.append(self.current)
            del self.history[:-HISTORY_LIMIT]
        self.current = url
        self.finished = None

    def _show(self, url):
        self.navigated_at = time.monotonic()
        self.title_before = self.media["title"] if self.media else None
        self.tv_title = None
        self.jobs.put(url)

    def _advance(self):
        if not self.queue:
            return False
        self._set_current(self.queue.pop(0))
        self._show(self.current)
        return True

    def _adopt_media(self, media):
        """Make media throw didn't start the TV's current video."""
        if not media or self._is_tv(media) or self._at_end(media):
            return
        if self._loading():
            return  # the old video is still reported while a link loads
        if self.tv_title is None and self.current not in (None, ADOPTED):
            # throw's own link started but was never recognised: this is it.
            self.tv_title = media["title"]
            return
        if self.current and self.current != ADOPTED:
            self.history.append(self.current)
            del self.history[:-HISTORY_LIMIT]
        self.current = ADOPTED
        self.tv_title = media["title"]
        self.finished = None
        # It may be playing in another window: find it afresh next time.
        self.window = None
        logger.info("adopting what's playing: %s", media["title"])

    def _is_idle(self):
        if self.current is None:
            return True
        if self._loading():
            return False
        if self._is_tv(self.media):
            return self._at_end(self.media)
        return True  # the TV window was closed or moved on

    # Links and remote controls.

    def play(self, url):
        with self.lock:
            self._set_current(url)
            self._show(url)

    def enqueue(self, url):
        with self.lock:
            # Queue behind whatever is on, even if throw didn't start it.
            self._adopt_media(self.media)
            if self._is_idle():
                self.play(url)
                return "playing"
            self.queue.append(url)
        threading.Thread(
            target=self._look_up, args=(url,), daemon=True
        ).start()
        return "queued"

    def _look_up(self, url):
        with self.lock:
            if url in self.video_info:
                return
        info = fetch_video_info(url) or {}
        with self.lock:
            self.video_info[url] = info
            # Forget links that have left the queue.
            for known in list(self.video_info):
                if known not in self.queue:
                    del self.video_info[known]

    def _queue_entry(self, url):
        info = self.video_info.get(url) or {}
        video_id = video_id_of(url)
        return {
            "title": info.get("title") or "YouTube video",
            "channel": info.get("channel") or "",
            "thumbnail": THUMBNAIL_URL.format(video_id) if video_id else None,
        }

    def next(self):
        with self.lock:
            if self._advance():
                return
            if not self.media:
                raise RequestError("nothing is playing", status_code=409)
        # Nothing queued: let YouTube skip to its own next video.
        firefox_command("next")

    def previous(self):
        with self.lock:
            if not self.history:
                firefox_command("position", "0")
                return
            if self.current and self.current != ADOPTED:
                self.queue.insert(0, self.current)
            self.current = self.history.pop()
            self.finished = None
            self._show(self.current)

    def stop(self):
        with self.lock:
            self.queue.clear()
            if self._is_tv(self.media):
                firefox_command("pause")

    def status(self):
        with self.lock:
            media = self.media
            if not media:
                return {"player": None}
            # While a thrown link loads, the old video is still reported;
            # it's on its way out, but it's still the TV's.
            is_tv = self._is_tv(media) or self._loading()
            return {
                "player": "tv" if is_tv else "firefox",
                "media-title": media["title"],
                "pause": media["state"] == "paused",
                "time-pos": media["position"],
                "duration": media["duration"],
                "volume": self.volume,
                "queue-length": len(self.queue) if is_tv else 0,
                "queue": (
                    [self._queue_entry(url) for url in self.queue]
                    if is_tv else []
                ),
                "can-volume": self.volume is not None,
                "can-queue": is_tv,
            }

    def is_showing_tv(self):
        with self.lock:
            return self._is_tv(self.media)

    def refresh(self):
        """Poll Firefox and the volume now, e.g. right after a control."""
        reported = get_firefox_media()
        volume = get_volume()
        with self.lock:
            media = self._with_clock(reported)
            self.media = media
            self.volume = volume
            self._check_finished(media)
            self._adopt_media(media)
            nudge = self._needs_timing(media)
        if nudge:
            threading.Thread(target=self._ask_for_timing, daemon=True).start()

    # The playback clock. Firefox passes on whatever position and length
    # the site reports; YouTube reports them only briefly after a seek and
    # never live. So remember each report and run the clock forward while
    # the media plays.

    @staticmethod
    def _new_clock(title):
        return {
            "title": title,
            "position": None,  # seconds, as of "at"
            "at": None,        # time.monotonic() of that position
            "duration": None,
            "playing": False,
            "report": None,    # the last (position, length) Firefox gave
            "nudged": False,   # already asked this video for its timing
        }

    def _estimate(self, now):
        clock = self.clock
        if clock["position"] is None:
            return None
        position = clock["position"]
        if clock["playing"]:
            position += now - clock["at"]
        if clock["duration"]:
            position = min(position, clock["duration"])
        return position

    def _with_clock(self, media):
        """Update the clock from Firefox's report; return timed media."""
        if media is None:
            return None
        now = time.monotonic()
        if media["title"] != self.clock["title"]:
            self.clock = self._new_clock(media["title"])
        clock = self.clock

        playing = media["state"] == "playing"
        if clock["position"] is not None and playing != clock["playing"]:
            # Paused or resumed: settle the position at this moment.
            clock["position"] = self._estimate(now)
            clock["at"] = now
        clock["playing"] = playing

        # A report counts only when it's new: YouTube repeats the same one
        # for a moment, and it describes the time of the seek, not now.
        if media["duration"]:
            report = (media["position"], media["duration"])
            if report != clock["report"]:
                clock["position"], clock["duration"] = report
                clock["at"] = now
            clock["report"] = report
        else:
            clock["report"] = None

        return {
            **media,
            "position": self._estimate(now) or 0,
            "duration": clock["duration"],
        }

    def _needs_timing(self, media):
        clock = self.clock
        if not media or media["state"] != "playing" or self._loading():
            return False
        if clock["duration"] is not None or clock["nudged"]:
            return False
        clock["nudged"] = True
        return True

    def _ask_for_timing(self):
        logger.info("asking the player for its position and length")
        run_playerctl("position", TIMING_NUDGE)
        # The report is brief: look a few times.
        for _attempt in range(3):
            time.sleep(0.5)
            self.refresh()

    def _check_finished(self, media):
        if not self.current or self.finished == self.current:
            return
        if self._loading() or not self._is_tv(media):
            return
        if self._at_end(media):
            logger.info("video finished")
            self.finished = self.current
            self._advance()  # does nothing once the queue is empty

    # The threads.

    def _watch(self):
        while True:
            try:
                self.refresh()
            except Exception:
                logger.exception("watching Firefox failed")
            time.sleep(WATCH_INTERVAL_SECONDS)

    def _work(self):
        while True:
            url = self.jobs.get()
            # If several links arrived while busy, only the latest matters.
            while not self.jobs.empty():
                url = self.jobs.get_nowait()
            try:
                self._display(url)
            except ToolError as error:
                logger.error("couldn't show the link on the TV: %s", error)
            except Exception:
                logger.exception("couldn't show the link on the TV")

    def _display(self, url):
        wait_for_session()  # just after boot, Hyprland may still be starting
        # Whatever was playing (another tab, Spotify) shouldn't carry on
        # underneath the new link.
        pause_all_playback()
        window = self.window
        if window is None or hypr_client(window) is None:
            # Prefer taking over a Firefox window that's already open.
            window = self._find_existing_window()
            self.window = window
        if window is None:
            window = self._open_window(url)
            self.window = window
        else:
            logger.info("navigating the TV window")
            # In YouTube's fullscreen, Firefox ignores Ctrl+L and the keys
            # reach the page instead, where "/" opens YouTube's search box.
            # So leave fullscreen first; Escape is harmless otherwise.
            send_keys(
                window,
                "-k", "Escape",
                "-s", str(FULLSCREEN_EXIT_MS),
                "-M", "ctrl", "-k", "l", "-m", "ctrl",  # the address bar
                "-s", str(ADDRESS_BAR_MS),
                url,
                "-k", "Return",
            )
        with self.lock:
            self.navigated_at = time.monotonic()
        self._fullscreen_when_playing(window)

    def _find_existing_window(self):
        """The open Firefox window best suited to become the TV, if any."""
        windows = [
            client for client in hypr_clients()
            if client.get("class") == "firefox"
            and client.get("title") not in NOT_TV_WINDOW_TITLES
        ]
        if not windows:
            return None
        with self.lock:
            media_title = self.media["title"] if self.media else None

        def preference(client):
            # A window's title is its active tab's title, so the window
            # whose title contains the playing media's title is playing it.
            title = client.get("title", "")
            plays_media = bool(media_title) and media_title in title
            shows_youtube = "YouTube" in title
            recency = client.get("focusHistoryID", 99)
            return (not plays_media, not shows_youtube, recency)

        chosen = min(windows, key=preference)
        logger.info("taking over Firefox window: %s", chosen.get("title"))
        return chosen["address"]

    def _open_window(self, url):
        logger.info("opening the TV window")
        before = {client.get("address") for client in hypr_clients()}
        open_in_new_window(url)
        deadline = time.monotonic() + WINDOW_APPEAR_SECONDS
        while time.monotonic() < deadline:
            time.sleep(0.3)
            new = [
                client for client in hypr_clients()
                if client.get("class") == "firefox"
                and client.get("address") not in before
            ]
            if new:
                # Firefox may restore old windows alongside ours; ours is
                # the one it focused last.
                time.sleep(WINDOW_SETTLE_SECONDS)
                new = [
                    client for client in hypr_clients()
                    if client.get("class") == "firefox"
                    and client.get("address") not in before
                ]
                newest = min(new, key=lambda c: c.get("focusHistoryID", 99))
                return newest["address"]
        raise ToolError("the TV window didn't appear")

    def _fullscreen_when_playing(self, window):
        """Once the new video plays, remember it and go fullscreen."""
        started = time.monotonic()
        while time.monotonic() - started < PLAYBACK_START_SECONDS:
            time.sleep(0.5)
            media = get_firefox_media()
            if not media or media["state"] != "playing":
                continue
            elapsed = time.monotonic() - started
            # A different title, or a position consistent with having just
            # started, means it's the new video rather than the old one.
            fresh = (
                media["title"] != self.title_before
                or media["position"] < elapsed + 2
            )
            if fresh:
                with self.lock:
                    self.tv_title = media["title"]
                break
        else:
            logger.warning("the TV didn't start playing")
            return

        time.sleep(FULLSCREEN_DELAY_SECONDS)
        for attempt in range(1, FULLSCREEN_ATTEMPTS + 1):
            if self._is_fullscreen(window):
                return
            send_keys(window, "f")  # YouTube's own fullscreen player
            # "f" toggles, so only press again once it has clearly failed.
            if self._wait_for_fullscreen(window):
                logger.info("TV is fullscreen (attempt %d)", attempt)
                return
            time.sleep(attempt)  # give the player longer each time
        logger.warning("couldn't make the TV fullscreen")

    def _is_fullscreen(self, window):
        client = hypr_client(window)
        return bool(client and client.get("fullscreen"))

    def _wait_for_fullscreen(self, window):
        deadline = time.monotonic() + FULLSCREEN_CONFIRM_SECONDS
        while time.monotonic() < deadline:
            if self._is_fullscreen(window):
                return True
            time.sleep(0.25)
        return False


tv = TvController()


# --- remote actions ----------------------------------------------------

def play_now(url):
    youtube_url = youtube_watch_url(url)
    if youtube_url is None:
        open_in_new_window(url)
        return "opened in browser"
    tv.play(youtube_url)
    return "playing"


def add_to_queue(url):
    youtube_url = youtube_watch_url(url)
    if youtube_url is None:
        raise RequestError("only YouTube links can be queued")
    return tv.enqueue(youtube_url)


def get_status():
    return tv.status()


def parse_number(params, key, default):
    raw_value = params.get(key, default)
    try:
        number = float(raw_value)
    except ValueError:
        raise RequestError(f"{key} must be a number, got {raw_value!r}")
    if not math.isfinite(number):
        raise RequestError(f"{key} must be finite, got {raw_value!r}")
    return number


def require_media():
    if tv.status()["player"] is None:
        raise RequestError("nothing is playing", status_code=409)


def toggle_pause(params):
    require_media()
    firefox_command("play-pause")
    tv.refresh()


def next_item(params):
    if tv.is_showing_tv():
        tv.next()
    else:
        require_media()
        firefox_command("next")


def previous_item(params):
    if tv.is_showing_tv():
        tv.previous()
    else:
        require_media()
        firefox_command("previous")


def stop(params):
    """Pause the TV and clear its queue."""
    tv.stop()
    tv.refresh()


def seek(params):
    """?t=+30 / ?t=-10 seeks relatively; ?to=90 jumps to 1:30."""
    require_media()
    if "to" in params:
        seconds = parse_number(params, "to", "0")
        firefox_command("position", f"{seconds:g}")
    else:
        offset = parse_number(params, "t", "10")
        direction = "+" if offset >= 0 else "-"
        firefox_command("position", f"{abs(offset):g}{direction}")
    # The player reports where it landed a moment later: catch that.
    time.sleep(SEEK_REPORT_SECONDS)
    tv.refresh()


def change_volume(params):
    """?v=+5 or ?v=-5 is relative; ?v=60 sets an absolute level."""
    amount = parse_number(params, "v", "+5")
    relative = params.get("v", "+5").startswith(("+", "-"))
    set_volume(amount, relative)
    tv.refresh()


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
        elif path in LINK_PATHS:
            self.handle_link(path, params, body)
        else:
            raise RequestError(f"unknown endpoint {path}", status_code=404)

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
            result = play_now(url)  # /play, or a link sent to /

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
        try:
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError):
            # The client left before the reply (a phone locking, say):
            # nothing to do, and not worth a traceback.
            pass

    def log_request(self, code="-", size="-"):
        # Log the path only: the query string may carry the token.
        path = urllib.parse.urlparse(self.path).path
        status = getattr(code, "value", code)
        if path in QUIET_PATHS and status == 200:
            return
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
    for tool in ("hyprctl", "wtype", "playerctl", "wpctl", "firefox"):
        if shutil.which(tool) is None:
            logger.warning("%s is not installed; throw needs it", tool)
    tv.start()
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
