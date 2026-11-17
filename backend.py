#!/usr/bin/env python3
"""Read a local directory without shell interpolation or file mutation."""
import json
import os
import sys

MAX_ENTRIES = 5000
MAX_PATH = 8192


def listing(request, base, hidden=False):
    if not isinstance(request, str) or len(request) > MAX_PATH or '\0' in request:
        return {'error': 'invalid'}
    request = request or os.path.expanduser('~')
    if request == '~' or request.startswith('~/'):
        request = os.path.expanduser('~') + request[1:]
    path = os.path.abspath(os.path.join(base, request))
    try:
        entries = []
        truncated = False
        with os.scandir(path) as iterator:
            for entry in iterator:
                if not hidden and entry.name.startswith('.'):
                    continue
                if len(entries) >= MAX_ENTRIES:
                    truncated = True
                    break
                try:
                    directory = entry.is_dir(follow_symlinks=True)
                except OSError:
                    directory = False
                entries.append({'name': entry.name, 'path': entry.path, 'directory': directory})
        entries.sort(key=lambda e: (not e['directory'], e['name'].casefold(), e['name']))
        return {'path': path, 'parent': os.path.dirname(path), 'entries': entries,
                'truncated': truncated, 'error': ''}
    except PermissionError:
        return {'error': 'permission'}
    except (FileNotFoundError, NotADirectoryError):
        return {'error': 'missing'}
    except (OSError, ValueError):
        return {'error': 'invalid'}


if __name__ == '__main__':
    # Bound even remote filesystem operations; the shell remains responsive.
    import signal
    signal.signal(signal.SIGALRM, lambda *_: sys.exit(2))
    signal.alarm(10)
    print(json.dumps(listing(sys.argv[1], sys.argv[2], sys.argv[3] == 'true'), ensure_ascii=True))
