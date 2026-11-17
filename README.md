# Home Browser for Omarchy

Browse your home directory and the filesystem from a popup in the Omarchy bar. Plugin ID: `aitor.home-browser`.

Click the folder icon to open your home directory. Click a folder to enter it or a file to open it with its default application. The editable address bar accepts absolute paths, paths relative to the displayed folder, `~`, and `~/…`.

The toolbar provides Back, Up, Home, hidden files and Refresh. Folders appear first and the list scrolls. Escape or a click outside closes the popup. Every opening starts at Home. **Open in file manager** opens the displayed folder externally.

## Requirements

- Omarchy 4.5, including its Quickshell shell and shared UI components.
- Python 3, with only the standard library. Available on a standard Omarchy installation.
- A desktop application associated with each file type you want to open.

No additional runtime packages, account, API key or setup script are required. Tests also use Node.js and the installed Omarchy language registry and plural engine.

## Install

```bash
omarchy plugin add https://github.com/aitorcalero/omarchy-home-browser.git --enable
```

The plugin defaults to the left section of the bar. To place it beside the workspaces:

```bash
omarchy bar move aitor.home-browser --after omarchy.workspaces
```

User plugin files and shell configuration hot-reload without restarting the shell.

## Disable or remove

```bash
omarchy plugin disable aitor.home-browser
omarchy plugin remove aitor.home-browser
```

Disabling keeps the installed files. Removing deletes the plugin through Omarchy's plugin manager.

## Languages and appearance

Includes complete catalogs for all 50 languages in Omarchy 4.5's language registry, plus an `es` fallback. The panel follows **Setup > Language** immediately, including right-to-left layouts, localized numbers and the shell's plural rules. Filesystem paths retain their left-to-right order.

The plugin uses Omarchy's Panel, KeyboardPanel, Button and TextField components and follows the active theme and animation settings.

## File access and limits

Directory reading runs in a Python subprocess with a ten-second deadline. The plugin reads the directory you navigate to and passes files you explicitly click to their associated desktop application. Those applications may modify files according to their own behavior.

The plugin itself does not modify your files, make network requests, interpolate commands through a shell, request elevated privileges or collect telemetry. Filenames and tooltips render as plain text. Symbolic links to directories can be followed. Hidden files are off initially and can be shown with the toolbar control.

Listings refresh when you navigate, reopen the panel, toggle hidden files or press Refresh. A listing is capped at 5000 entries with a visible warning. Larger directories should be opened in the file manager; the displayed subset is sorted after enumeration and is not guaranteed to contain the first 5000 alphabetical entries.

## Development and verification

On an Omarchy 4.5 machine, from the repository root:

```bash
omarchy plugin validate .
python3 -m unittest discover -v
```

Five regression tests cover navigation, special and markup-shaped filenames, hidden files, symlinks, invalid paths, listing limits, plain-text display sinks, catalog completeness, placeholders and all required plural forms against the installed Omarchy engine.

The panel has also been checked in the running shell for absolute and relative navigation, Back, invalid-path recovery and home expansion. Live language changes for all 50 catalogs were checked with Omarchy's translation component in an isolated Quickshell instance.

## License

[MIT](LICENSE).
