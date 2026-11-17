import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).parent
spec = importlib.util.spec_from_file_location('backend', ROOT / 'backend.py')
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)


class BrowserTests(unittest.TestCase):
    def test_navigation_and_literal_names(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'folder').mkdir()
            (root / '.hidden').touch()
            names = ['<img src="https:tracker">', 'a #?%.txt', '$(touch PWNED)', 'á\nline.txt']
            for name in names:
                (root / name).touch()
            result = backend.listing(tmp, '/')
            self.assertEqual(result['entries'][0]['name'], 'folder')
            self.assertEqual({e['name'] for e in result['entries']}, set(names + ['folder']))
            self.assertEqual(len(backend.listing(tmp, '/', True)['entries']), 6)
            self.assertEqual(backend.listing('folder/..', tmp)['path'], tmp)
            self.assertEqual(backend.listing('folder', tmp)['entries'], [])
            self.assertEqual(backend.listing('missing', tmp)['error'], 'missing')
            self.assertEqual(backend.listing(names[1], tmp)['error'], 'missing')
            (root / 'link').symlink_to(root / 'folder')
            self.assertEqual(backend.listing('link', tmp)['entries'], [])

    def test_invalid_and_bound(self):
        self.assertEqual(backend.listing('\0', '/')['error'], 'invalid')
        self.assertEqual(backend.listing('a' * 8193, '/')['error'], 'invalid')
        with tempfile.TemporaryDirectory() as tmp:
            for n in range(4):
                (Path(tmp) / str(n)).touch()
            limit = backend.MAX_ENTRIES
            try:
                backend.MAX_ENTRIES = 3
                result = backend.listing(tmp, '/')
                self.assertTrue(result['truncated'])
                self.assertEqual(len(result['entries']), 3)
            finally:
                backend.MAX_ENTRIES = limit

    def test_dynamic_display_sinks_are_plain(self):
        # Regression: malicious filenames reach only the shared Button's
        # explicit PlainText label and PlainText tooltip, never AutoText.
        shared = Path('/usr/share/omarchy/shell/Ui/Button.qml').read_text()
        self.assertIn('textFormat: Text.PlainText\n      text: root.tooltipText', shared)
        self.assertIn('textFormat: Text.PlainText\n      visible: root.text', shared)
        panel = (ROOT / 'Panel.qml').read_text()
        self.assertIn('text: modelData.name', panel)
        self.assertIn('tooltipText: modelData.name', panel)
        self.assertIn('path.split("/").map(encodeURIComponent).join("/")', panel)


if __name__ == '__main__':
    unittest.main()
