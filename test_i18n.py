"""Validate coverage against the installed Omarchy registry and plural engine."""
from pathlib import Path
import json
import re
import subprocess
import unittest

ROOT = Path(__file__).parent
OMARCHY = Path('/usr/share/omarchy')


class TranslationTests(unittest.TestCase):
    def test_complete_catalogs_and_placeholders(self):
        registry = json.loads((OMARCHY / 'default/i18n/locales.json').read_text())
        english = json.loads((ROOT / 'i18n/en.json').read_text())
        for code in registry:
            with self.subTest(language=code):
                catalog = json.loads((ROOT / 'i18n' / (code + '.json')).read_text())
                self.assertEqual(set(catalog), set(english))
                for key, reference in english.items():
                    value = catalog[key]
                    if isinstance(reference, dict):
                        self.assertIsInstance(value, dict)
                        for form in value.values():
                            self.assertIsInstance(form, str)
                            self.assertTrue(form.strip())
                            self.assertEqual(re.findall(r'%\d+', form), ['%1'])
                    else:
                        self.assertIsInstance(value, str)
                        self.assertTrue(value.strip())
                        self.assertEqual(re.findall(r'%\d+', value), re.findall(r'%\d+', reference))

    def test_all_plural_forms_match_shell_rules(self):
        script = r'''
const fs = require('fs');
const assert = require('assert');
const plural = require('/usr/share/omarchy/shell/Commons/Plural.js');
const locales = require('/usr/share/omarchy/default/i18n/locales.json');
for (const code of Object.keys(locales)) {
  const catalog = JSON.parse(fs.readFileSync(process.argv[1] + '/i18n/' + code + '.json', 'utf8'));
  assert.deepStrictEqual(Object.keys(catalog.count).sort(), plural.categories(code).sort(), code);
  for (const n of [0, 1, 2, 3, 4, 5, 6, 10, 11, 12, 19, 20, 21, 22, 100, 101, 102, 1000, 5000, 1000000]) {
    assert.strictEqual(plural.pick(catalog.count, code, n), catalog.count[plural.category(code, n)], code);
  }
}
console.log('All 50 catalogs match the shell plural engine.');
'''
        subprocess.run(['node', '-e', script, str(ROOT)], check=True, capture_output=True, text=True)


if __name__ == '__main__':
    unittest.main()
