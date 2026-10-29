#!/usr/bin/env python3
"""Simple graphical package manager for the andreas-pc NixOS configuration."""

import json
import os
import re
import subprocess
import threading
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk  # noqa: E402


def find_config():
    if configured := os.environ.get("CONFIG"):
        return Path(configured).resolve()
    cwd = Path.cwd()
    if (cwd / "nixos/flake.nix").is_file():
        return cwd
    if (cwd / "flake.nix").is_file() and (cwd / "custom/andreas-pc.nix").is_file():
        return cwd.parent
    return Path("/home/andreas/dev/config")


CONFIG = find_config()
HOST_CONFIG = CONFIG / "nixos/custom/andreas-pc.nix"
FLAKE = CONFIG / "nixos"
READ_ONLY = os.environ.get("ANDREAS_SOFTWARE_READ_ONLY") == "1"


def installed_packages():
    result = []
    inside = False
    for raw in HOST_CONFIG.read_text().splitlines():
        if "environment.systemPackages = with pkgs; [" in raw:
            inside = True
            continue
        if inside and raw.strip() == "];":
            break
        if not inside:
            continue
        line = raw.split("#", 1)[0].strip()
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.-]*", line):
            result.append(line)
    return result


def nixpkgs_ref():
    lock = json.loads((FLAKE / "flake.lock").read_text())
    root = lock["nodes"][lock["root"]]
    node_name = root["inputs"]["nixpkgs-andreas"]
    if isinstance(node_name, list):
        node_name = node_name[-1]
    locked = lock["nodes"][node_name]["locked"]
    if locked.get("type") == "github":
        return f"github:{locked['owner']}/{locked['repo']}/{locked['rev']}"
    return "nixpkgs"


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="de.xunil.AndreasSoftware")
        self.ref = nixpkgs_ref()
        self.generation = 0
        self.search_timer = None
        self.rows = []

    def do_activate(self):
        window = Gtk.ApplicationWindow(application=self)
        window.set_title("Programme verwalten")
        window.set_default_size(900, 620)
        window.set_border_width(18)

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        title = Gtk.Label()
        title.set_markup("<span size='xx-large' weight='bold'>Programme verwalten</span>")
        title.set_xalign(0)
        outer.pack_start(title, False, False, 0)

        self.search = Gtk.SearchEntry(placeholder_text="Programm suchen, z. B. Firefox oder Bildbearbeitung")
        self.search.connect("search-changed", self.on_search_changed)
        outer.pack_start(self.search, False, False, 0)

        paned = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL)
        outer.pack_start(paned, True, True, 0)

        self.store = Gtk.ListStore(str, str, str, bool)
        self.view = Gtk.TreeView(model=self.store)
        self.view.append_column(Gtk.TreeViewColumn("Programm", Gtk.CellRendererText(), text=1))
        self.view.append_column(Gtk.TreeViewColumn("Version", Gtk.CellRendererText(), text=2))
        self.view.get_selection().connect("changed", self.on_selected)
        scroll = Gtk.ScrolledWindow()
        scroll.add(self.view)
        paned.pack1(scroll, resize=True, shrink=False)

        details = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        details.set_border_width(14)
        self.name = Gtk.Label(label="Programm auswählen")
        self.name.set_xalign(0)
        self.name.set_line_wrap(True)
        self.description = Gtk.Label(label="Die Suche durchsucht die Pakete der installierten NixOS-Version.")
        self.description.set_xalign(0)
        self.description.set_yalign(0)
        self.description.set_line_wrap(True)
        self.description.set_selectable(True)
        details.pack_start(self.name, False, False, 0)
        details.pack_start(self.description, False, False, 0)
        details.pack_start(Gtk.Separator(), False, False, 4)
        self.action = Gtk.Button(label="Installieren")
        self.action.set_sensitive(False)
        if READ_ONLY:
            self.action.set_tooltip_text("Im Testmodus sind Änderungen deaktiviert.")
        self.action.connect("clicked", self.on_action)
        details.pack_start(self.action, False, False, 0)
        details.pack_start(Gtk.Label(), True, True, 0)
        paned.pack2(details, resize=False, shrink=False)
        paned.set_position(570)

        self.status = Gtk.Label(label="Suchbegriff eingeben oder „Installiert“ anzeigen.")
        self.status.set_xalign(0)
        bottom = Gtk.Box(spacing=10)
        installed = Gtk.Button(label="Installierte Programme")
        installed.connect("clicked", lambda *_: self.show_installed())
        bottom.pack_start(self.status, True, True, 0)
        bottom.pack_end(installed, False, False, 0)
        outer.pack_start(bottom, False, False, 0)

        window.add(outer)
        window.show_all()
        self.window = window
        self.search.grab_focus()

    def on_search_changed(self, entry):
        if self.search_timer:
            GLib.source_remove(self.search_timer)
        query = entry.get_text().strip()
        if not query:
            self.store.clear()
            self.status.set_text("Suchbegriff eingeben oder „Installiert“ anzeigen.")
            return
        self.search_timer = GLib.timeout_add(450, self.start_search, query)

    def start_search(self, query):
        self.search_timer = None
        self.generation += 1
        generation = self.generation
        self.status.set_text("Suche läuft …")
        self.search.set_progress_pulse_step(0.1)
        self.search.progress_pulse()
        threading.Thread(target=self.search_worker, args=(query, generation), daemon=True).start()
        return False

    def search_worker(self, query, generation):
        # A subsequence regex gives useful fuzzy matches: "firfox" can find firefox.
        words = [".*".join(map(re.escape, word)) for word in query.split()]
        pattern = ".*".join(words)
        try:
            proc = subprocess.run(
                ["nix", "search", "--json", self.ref, pattern],
                text=True, capture_output=True, timeout=90,
            )
            data = json.loads(proc.stdout or "{}")
            rows = []
            for full_attr, info in data.items():
                attr = re.sub(r"^legacyPackages\.[^.]+\.", "", full_attr)
                rows.append((attr, info.get("pname") or attr, info.get("version", ""), info.get("description", "")))
            rows.sort(key=lambda row: (query.lower() not in row[1].lower(), len(row[1]), row[1].lower()))
            GLib.idle_add(self.finish_search, rows[:200], generation, None)
        except Exception as exc:
            GLib.idle_add(self.finish_search, [], generation, str(exc))

    def finish_search(self, rows, generation, error):
        if generation != self.generation:
            return False
        self.rows = rows
        self.store.clear()
        installed = set(installed_packages())
        for attr, pname, version, _description in rows:
            self.store.append((attr, pname, version, attr in installed))
        self.search.set_progress_fraction(0)
        if error:
            self.status.set_text(f"Suche fehlgeschlagen: {error}")
        else:
            self.status.set_text(f"{len(rows)} Ergebnisse" if rows else "Keine Programme gefunden.")
        return False

    def show_installed(self):
        self.generation += 1
        packages = installed_packages()
        self.rows = [(p, p, "", "Installiertes Systempaket") for p in packages]
        self.store.clear()
        for attr, name, version, _ in self.rows:
            self.store.append((attr, name, version, True))
        self.status.set_text(f"{len(packages)} installierte Programme")

    def on_selected(self, selection):
        model, tree_iter = selection.get_selected()
        if tree_iter is None:
            self.action.set_sensitive(False)
            return
        attr = model[tree_iter][0]
        matching = next((r for r in self.rows if r[0] == attr), None)
        description = matching[3] if matching else ""
        is_installed = bool(model[tree_iter][3])
        self.name.set_markup(f"<span size='x-large' weight='bold'>{GLib.markup_escape_text(model[tree_iter][1])}</span>")
        self.description.set_text(f"Paketname: {attr}\n\n{description or 'Keine Beschreibung vorhanden.'}")
        self.action.set_label("Entfernen" if is_installed else "Installieren")
        self.action.set_sensitive(not READ_ONLY)
        self.action.package = attr
        self.action.remove = is_installed
        if READ_ONLY:
            self.status.set_text("Testmodus: Installieren und Entfernen sind deaktiviert.")

    def on_action(self, button):
        verb = "entfernt" if button.remove else "installiert"
        dialog = Gtk.MessageDialog(
            transient_for=self.window, modal=True, message_type=Gtk.MessageType.QUESTION,
            buttons=Gtk.ButtonsType.OK_CANCEL,
            text=f"„{button.package}“ wirklich {verb}?",
        )
        dialog.format_secondary_text("Danach wird NixOS neu gebaut. Das kann einige Minuten dauern.")
        accepted = dialog.run() == Gtk.ResponseType.OK
        dialog.destroy()
        if not accepted:
            return
        self.action.set_sensitive(False)
        self.status.set_text("Änderung wird angewendet … Bitte die Passwortabfrage bestätigen.")
        threading.Thread(target=self.change_worker, args=(button.package, button.remove), daemon=True).start()

    def change_worker(self, package, remove):
        script = CONFIG / "scripts" / ("remove-andreas-software.sh" if remove else "add-andreas-software.sh")
        env = dict(os.environ, CONFIG=str(CONFIG), ANDREAS_SOFTWARE_GUI="1")
        proc = subprocess.run([str(script), package], text=True, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, env=env)
        GLib.idle_add(self.finish_change, package, proc.returncode, proc.stdout)

    def finish_change(self, package, returncode, output):
        dialog = Gtk.MessageDialog(
            transient_for=self.window, modal=True,
            message_type=Gtk.MessageType.INFO if returncode == 0 else Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.CLOSE,
            text="Änderung erfolgreich" if returncode == 0 else "Änderung fehlgeschlagen",
        )
        dialog.format_secondary_text(output[-5000:] or "Keine Ausgabe.")
        dialog.run()
        dialog.destroy()
        self.status.set_text(
            f"„{package}“ wurde geändert." if returncode == 0 else "Änderung fehlgeschlagen."
        )
        self.action.set_sensitive(True)
        self.show_installed()
        return False


if __name__ == "__main__":
    raise SystemExit(App().run())
