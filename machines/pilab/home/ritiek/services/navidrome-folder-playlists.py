#!/usr/bin/env python3
"""Generate one Navidrome M3U playlist per music folder.

Ordering strategy per folder:
  1. Tracks listed in a sibling *.spotdl file are ordered by their Spotify
     playlist position (list_position).
  2. Tracks that could not be matched to the playlist (removed from Spotify,
     metadata drift, or folders without a .spotdl file) are appended
     chronologically by download date (mtime).
"""

import json
import os
import re
import subprocess
import sys
import unicodedata

MUSIC_DIR = "/media/HOMELAB_MEDIA/services/spotdl"
PLAYLISTS_DIR = os.path.join(MUSIC_DIR, "_playlists")
NAVIDROME_PORT = 14533
MARKER = "# managed-by-navidrome-folder-playlists"
AUDIO_EXTS = (".mp3", ".flac", ".m4a", ".aac", ".ogg", ".opus", ".wav", ".wma")


def norm(s):
    """Aggressive normalization for fuzzy filename matching."""
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = s.lower().replace("&", "and")
    return " ".join(re.findall(r"[a-z0-9]+", s))


def is_audio(name):
    return name.lower().endswith(AUDIO_EXTS)


def collect_files(folder):
    """Recursively collect audio files under folder, as relative POSIX paths."""
    hits = []
    for root, dirs, files in os.walk(folder):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for f in files:
            if is_audio(f):
                hits.append(os.path.relpath(os.path.join(root, f), folder))
    return hits


def load_songs(folder):
    songs = []
    for f in os.listdir(folder):
        if f.endswith(".spotdl"):
            try:
                with open(os.path.join(folder, f)) as fh:
                    songs.extend(json.load(fh)["songs"])
            except (json.JSONDecodeError, KeyError, OSError):
                pass
    return songs


def spotify_sort_key(song):
    pos = song.get("list_position")
    return (pos is None, pos or 0)


def match_song(song, nbase, titles, used):
    arts = song.get("artists", [])
    artist_str = ", ".join(arts) if isinstance(arts, list) else str(arts)
    nk = norm(artist_str + " - " + song["name"])
    if nk in nbase and nbase[nk] not in used:
        return nbase[nk]

    tn = norm(song["name"])
    if not tn:
        return None
    opts = [v for v in titles.get(tn, []) if v not in used]
    if len(opts) == 1:
        return opts[0]

    opts = [f for k, f in nbase.items() if tn in k and f not in used]
    if len(opts) == 1:
        return opts[0]
    return None


def order_folder(folder):
    """Return ordered list of relative paths: Spotify order first, then by mtime."""
    rels = collect_files(folder)
    base = {os.path.splitext(r)[0]: r for r in rels}
    nbase = {norm(k): v for k, v in base.items()}
    titles = {}
    for nk, v in nbase.items():
        titles.setdefault(nk, []).append(v)

    songs = sorted(load_songs(folder), key=spotify_sort_key)
    ordered, used = [], set()
    for song in songs:
        hit = match_song(song, nbase, titles, used)
        if hit:
            used.add(hit)
            ordered.append(hit)

    rest = sorted(
        (r for r in rels if r not in used),
        key=lambda r: os.path.getmtime(os.path.join(folder, r)),
    )
    return ordered + rest


def trigger_scan():
    try:
        import hashlib
        import urllib.parse
        import urllib.request

        env = {}
        secret = "/home/ritiek/.config/sops-nix/secrets/navidrome.env"
        if not os.path.isfile(secret):
            print("navidrome.env secret missing; skipping scan trigger")
            return
        with open(secret) as fh:
            for line in fh:
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    k, _, v = line.partition("=")
                    env[k.strip()] = v.strip()

        r = subprocess.run(
            ["systemctl", "is-active", "--quiet", "docker-navidrome.service"],
            capture_output=True,
        )
        if r.returncode != 0:
            print("navidrome is not running; playlists will be imported on next start/scan")
            return

        salt = os.urandom(8).hex()
        token = hashlib.md5((env["NAVIDROME_PASSWORD"] + salt).encode()).hexdigest()
        user = urllib.parse.quote(env["NAVIDROME_USER"], safe="")
        url = (
            f"http://127.0.0.1:{NAVIDROME_PORT}/rest/startScan"
            f"?u={user}&t={token}&s={salt}&v=1.16.1&c=spotdl-sync&f=json"
        )
        with urllib.request.urlopen(url, timeout=10) as resp:
            print("Triggered navidrome scan." if resp.status == 200 else f"scan HTTP {resp.status}")
    except Exception as exc:  # noqa: BLE001 - never fail the sync service over this
        print(f"Warning: failed to trigger navidrome scan: {exc}")


def main():
    if not os.path.isdir(MUSIC_DIR):
        sys.exit(1)
    os.makedirs(PLAYLISTS_DIR, exist_ok=True)

    for entry in sorted(os.listdir(MUSIC_DIR)):
        folder = os.path.join(MUSIC_DIR, entry)
        if not os.path.isdir(folder) or entry.startswith("."):
            continue

        tracks = order_folder(folder)
        target = os.path.join(PLAYLISTS_DIR, entry + ".m3u")
        tmp = target + ".tmp"

        with open(tmp, "w") as fh:
            fh.write("#EXTM3U\n" + MARKER + "\n")
            for t in tracks:
                fh.write("../" + entry + "/" + t.replace(os.sep, "/") + "\n")

        if len(tracks) > 0:
            os.replace(tmp, target)
            print(f"Generated {target} ({len(tracks)} tracks)")
        else:
            os.remove(tmp)
            if os.path.exists(target):
                os.remove(target)

    # Remove orphaned managed playlists whose folder disappeared
    for pls in os.listdir(PLAYLISTS_DIR):
        if not pls.endswith(".m3u"):
            continue
        path = os.path.join(PLAYLISTS_DIR, pls)
        with open(path) as fh:
            content = fh.read()
        if MARKER not in content:
            continue
        name = pls[:-4]
        folder = os.path.join(MUSIC_DIR, name)
        has_audio = any(
            is_audio(f)
            for _, _, files in os.walk(folder)
            for f in files
        )
        if not has_audio:
            os.remove(path)
            print(f"Removed orphaned {path}")

    trigger_scan()


if __name__ == "__main__":
    main()
