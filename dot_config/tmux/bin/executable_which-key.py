#!/usr/bin/env python3
"""Keybind cheat sheet for a tmux popup, built live from `tmux list-keys`.

* Sections are guessed from each binding's command (SECTION_RULES below).
* Descriptions come from the binding's -N note, falling back to the command.
* Anything you changed from tmux's defaults is shown in a brighter colour, and
  is never hidden. Noisy *default* bindings are hidden (DENY_KEYS / DENY_CMDS).

Run it in a popup:  tmux display-popup -E ~/.config/tmux/which-key.py
"""
import os
import re
import shlex
import shutil
import subprocess
import sys

# ---------- layout (tweak these) ----------
KW = 13          # keycap column width, including its padding
DW = 34          # description column width
GAP = 4          # spaces between columns
MAXCOLS = 3      # never use more than this many columns

# ---------- what to show (tweak these) ----------
# Default tmux bindings matching these are hidden. Your own bindings never are.
DENY_KEYS = r"^M-|^[CS]-(Up|Down|Left|Right)$|^(DC|PPage|~|%|\\?\")$"
DENY_CMDS = r"^(send-prefix|suspend-client|show-messages|refresh-client|customize-mode|display-menu)\b"

# Hidden even if you bound them (they are not useful on a cheat sheet).
ALWAYS_HIDE_CMDS = r"^send-prefix\b"

SECTION_ORDER = ["Panes", "Windows", "Sessions", "Copy & paste", "Tools", "Misc"]

# First matching rule wins. Matched against the command with #{formats} removed.
# No match -> "Misc".
SECTION_RULES = [
    ("Copy & paste", r"copy-mode|paste-buffer|choose-buffer|list-buffers|delete-buffer|capture-pane|clear-history|save-buffer"),
    ("Sessions", r"new-session|switch-client|kill-session|rename-session|detach-client|choose-client|session|choose-tree\s+-\w*s\b"),
    ("Windows", r"new-window|kill-window|select-window|next-window|previous-window|last-window|rename-window|find-window|move-window|swap-window|link-window|unlink-window|respawn-window|choose-tree\s+-\w*w\b"),
    ("Panes", r"split-window|select-pane|resize-pane|swap-pane|break-pane|join-pane|kill-pane|display-panes|last-pane|rotate-window|select-layout|next-layout|previous-layout|respawn-pane|new-pane|zoom"),
    ("Tools", r"display-popup|run-shell|command-prompt|source-file|display-menu"),
]

# Descriptions that are rewritten, so related bindings collapse into one row.
DESC_FIXES = [
    (r"^Select window \d+$", "Go to window"),
]

# Used to name bindings that have no -N note.
VERBS = (r"new-session|switch-client|kill-session|rename-session|detach-client|new-window|kill-window|"
         r"select-window|next-window|previous-window|last-window|rename-window|find-window|move-window|"
         r"swap-window|split-window|select-pane|resize-pane|swap-pane|break-pane|join-pane|kill-pane|"
         r"display-panes|last-pane|select-layout|copy-mode|paste-buffer|choose-tree|source-file|"
         r"display-message|list-keys|clock-mode|display-popup|run-shell|command-prompt|send-keys")
WRAPPERS = {"display-popup", "run-shell", "command-prompt", "send-keys", "display-message"}

# Not tmux bindings, so they can't be read from list-keys. Edit freely.
STATIC = [
    ("Copy mode (vi)", [
        ("v", "Begin selection"),
        ("y", "Copy and exit"),
        ("/  ?", "Search forward / back"),
        ("n  N", "Next / previous match"),
        ("g  G", "Top / bottom"),
        ("C-u C-d", "Half page up / down"),
        ("q", "Quit copy mode"),
    ]),
    ("Mouse", [
        ("Click", "Focus pane / window tab"),
        ("Drag", "Select text / resize pane"),
        ("Scroll", "Enter copy mode and scroll"),
    ]),
]

BW = KW + 1 + DW
SEP = "\x1f"
FMT = SEP.join(["#{key_table}", "#{key_string}", "#{key_note}", "#{key_command}"])


# ---------- tmux helpers ----------
def tmux_out(*args):
    return subprocess.run(["tmux", *args], capture_output=True, text=True).stdout


def parse(out):
    for line in out.splitlines():
        parts = line.split(SEP, 3)
        if len(parts) == 4:
            yield parts  # table, key, note, command


def default_bindings():
    """tmux's stock bindings, from a throwaway server with no config."""
    sock = f"wk-defaults-{os.getpid()}"
    env = {k: v for k, v in os.environ.items() if k != "TMUX"}
    out = subprocess.run(
        ["tmux", "-L", sock, "-f", "/dev/null", "new-session", "-d", "-s", "x",
         ";", "list-keys", "-F", FMT],
        capture_output=True, text=True, env=env).stdout
    subprocess.run(["tmux", "-L", sock, "kill-server"], capture_output=True, env=env)
    return {(t, k): c for t, k, _, c in parse(out)}


def opt(name, default):
    return tmux_out("show", "-gqv", name).strip() or default


# ---------- colours (Noctalia palette, Mocha fallbacks) ----------
def sgr(fg=None, bg=None, bold=False):
    codes = ["1"] if bold else []
    if bg:
        codes.append("48;2;%d;%d;%d" % tuple(int(bg[i:i + 2], 16) for i in (1, 3, 5)))
    if fg:
        codes.append("38;2;%d;%d;%d" % tuple(int(fg[i:i + 2], 16) for i in (1, 3, 5)))
    return "\x1b[" + ";".join(codes) + "m"


RESET = "\x1b[0m"
C_HEAD = sgr(fg=opt("@noctalia_primary", "#cba6f7"), bold=True)
C_CHIP_PREFIX = sgr(fg=opt("@noctalia_on_surface", "#cdd6f4"),
                    bg=opt("@noctalia_surface_container_high", "#45475a"), bold=True)
C_CHIP_ROOT = sgr(fg=opt("@noctalia_on_primary_container", "#11111b"),
                  bg=opt("@noctalia_primary_container", "#89b4fa"), bold=True)
C_DESC = sgr(fg=opt("@noctalia_on_surface_variant", "#a6adc8"))
C_DESC_MINE = sgr(fg=opt("@noctalia_on_surface", "#cdd6f4"), bold=True)
C_DIM = sgr(fg=opt("@noctalia_outline", "#6c7086"))


# ---------- guessing ----------
def strip_formats(cmd):
    return re.sub(r"#\{[^}]*\}", "", cmd)


def guess_section(cmd):
    c = strip_formats(cmd)
    for name, pattern in SECTION_RULES:
        if re.search(pattern, c):
            return name
    return "Misc"


def humanize(name):
    name = re.sub(r"[-_]+", " ", name).strip()
    return name[:1].upper() + name[1:]


POPUP_ARG_FLAGS = {"-b", "-c", "-d", "-e", "-h", "-s", "-S", "-t", "-T", "-w", "-x", "-y"}


def popup_program(c):
    """The program a display-popup runs (list-keys prints it as the last argument)."""
    try:
        toks = shlex.split(c)
    except ValueError:
        return None
    if "display-popup" not in toks:
        return None
    i = toks.index("display-popup") + 1
    while i < len(toks):
        if toks[i] in POPUP_ARG_FLAGS:
            i += 2
        elif toks[i].startswith("-"):
            i += 1
        else:
            words = toks[i].split()
            return os.path.basename(words[0]) if words else None
    return None


def describe(cmd):
    """Name a binding that has no -N note."""
    c = strip_formats(cmd)
    # a script path inside run-shell / display-popup, e.g. ~/.config/tmux/which-key.sh
    if re.search(r"run-shell|display-popup", c):
        for path in re.findall(r"(?:~|/)[\w.~/-]+", c):
            if (re.search(r"\.(sh|py|bash)$", path) or path.startswith("~/")
                    or path.startswith(os.path.expanduser("~") + "/")):
                return humanize(re.sub(r"\.(sh|py|bash)$", "", os.path.basename(path)))
    # the program a popup launches, e.g. lazygit
    prog = popup_program(c)
    if prog and prog not in ("bash", "sh", "zsh"):
        return humanize(prog)
    # first meaningful tmux command mentioned
    for verb in re.findall(VERBS, c):
        if verb not in WRAPPERS:
            return humanize(verb)
    if prog:                                    # a plain shell popup
        return "Shell popup"
    words = c.split()
    return humanize(words[0]) if words else "?"


def clean_desc(note, cmd):
    desc = re.sub(r"^wk:", "", note).strip() or describe(cmd)
    for pattern, repl in DESC_FIXES:
        if re.search(pattern, desc):
            desc = repl
    desc = re.sub(r"\b(the|a|an|current|active)\s+", "", desc, flags=re.I)
    return desc[:1].upper() + desc[1:]


def pretty_key(key):
    if key.startswith("\\") and len(key) == 2:   # tmux escapes $ " ; and \
        key = key[1]
    return {"BTab": "S-Tab"}.get(key, key)


def compress_keys(keys):
    """Collapse 1 2 3 ... 9 into 1-9, and the four arrows into 'Arrows'."""
    keys = list(keys)
    digits = sorted(k for k in keys if len(k) == 1 and k.isdigit())
    if len(digits) >= 3 and [int(d) for d in digits] == list(range(int(digits[0]), int(digits[-1]) + 1)):
        at = keys.index(digits[0])
        keys = [k for k in keys if k not in digits]
        keys.insert(at, f"{digits[0]}-{digits[-1]}")
    for mod in ("C-", "M-", "S-"):
        group = [k for k in keys if len(k) == len(mod) + 1 and k.startswith(mod)]
        if len(group) >= 3:
            at = keys.index(group[0])
            keys = [k for k in keys if k not in group]
            keys.insert(at, mod + "/".join(k[-1] for k in group))
    arrows = {"Up", "Down", "Left", "Right"}
    if arrows <= set(keys):
        at = min(keys.index(a) for a in arrows)
        keys = [k for k in keys if k not in arrows]
        keys.insert(at, "Arrows")
    return keys


# ---------- build rows ----------
def collect():
    live = list(parse(tmux_out("list-keys", "-F", FMT)))
    defaults = default_bindings()
    groups = {}
    for table, key, note, cmd in live:
        if table not in ("prefix", "root"):
            continue
        custom = defaults.get((table, key)) != cmd
        if table == "root" and not custom:
            continue                       # stock root bindings are all mouse stuff
        if re.search(ALWAYS_HIDE_CMDS, cmd):
            continue
        if not custom and (re.search(DENY_KEYS, key) or re.search(DENY_CMDS, cmd)):
            continue
        section = guess_section(cmd)
        desc = clean_desc(note, cmd)
        g = groups.setdefault((section, table, desc),
                              {"keys": [], "custom": False, "order": len(groups)})
        g["keys"].append(pretty_key(key))
        g["custom"] = g["custom"] or custom
    return groups


def fit(text, width):
    return (text if len(text) <= width else text[:width - 1] + "…").ljust(width)


def chip(keys, kind):
    style = C_CHIP_ROOT if kind == "root" else C_CHIP_PREFIX
    return style + " " + fit(keys, KW - 2) + " " + RESET


def row(keys, desc, kind, mine):
    return chip(keys, kind) + " " + (C_DESC_MINE if mine else C_DESC) + fit(desc, DW) + RESET


def section_block(name, rows):
    blank = " " * BW
    return ([C_HEAD + name.ljust(BW) + RESET, C_DIM + "─" * BW + RESET] + rows + [blank])


def build_blocks(groups):
    by_section = {}
    for (section, table, desc), g in groups.items():
        by_section.setdefault(section, []).append((table, desc, g))
    blocks = []
    for section in SECTION_ORDER:
        items = by_section.get(section)
        if not items:
            continue
        # yours first, then defaults; prefix before no-prefix; otherwise list-keys order
        items.sort(key=lambda it: (not it[2]["custom"], it[0] != "prefix", it[2]["order"]))
        rows = [row(" ".join(compress_keys(g["keys"])), desc, table, g["custom"])
                for table, desc, g in items]
        blocks.append(section_block(section, rows))
    for name, entries in STATIC:
        blocks.append(section_block(name, [row(k, d, "root", False) for k, d in entries]))
    return blocks


def layout(blocks, width):
    ncols = max(1, min(MAXCOLS, (width - 4 + GAP) // (BW + GAP)))
    cols = [[] for _ in range(ncols)]
    for blk in blocks:
        cols[min(range(ncols), key=lambda i: len(cols[i]))].extend(blk)
    height = max(len(c) for c in cols)
    gap = " " * GAP
    return ["  " + gap.join(c[r] if r < len(c) else " " * BW for c in cols)
            for r in range(height)]


def main():
    width, height = shutil.get_terminal_size((120, 40))
    prefix = tmux_out("show", "-gqv", "prefix").strip() or "C-b"
    body = layout(build_blocks(collect()), width)

    legend = (f"  {chip('prefix', 'prefix')} then key   {chip('no prefix', 'root')}   "
              f"{C_DESC_MINE}bright{RESET}{C_DIM} = yours{RESET}")
    out = ["", f"  {C_HEAD}Keybinds{RESET}   {C_DIM}prefix: {prefix}{RESET}", legend, ""] + body

    if len(out) + 1 > height and shutil.which("less"):
        out.append(f"  {C_DIM}j/k to scroll, q to close{RESET}")
        subprocess.run(["less", "-R"], input=("\n".join(out) + "\n").encode())
    else:
        out.append(f"  {C_DIM}press any key to close{RESET}")
        print("\n".join(out))
        try:
            import termios
            import tty
            fd = sys.stdin.fileno()
            old = termios.tcgetattr(fd)
            try:
                tty.setraw(fd)
                sys.stdin.read(1)
            finally:
                termios.tcsetattr(fd, termios.TCSADRAIN, old)
        except Exception:
            input()


if __name__ == "__main__":
    main()
