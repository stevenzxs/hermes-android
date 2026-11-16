import pathlib
import unittest
from scripts.verify_release_apks import PACKAGE_NAME, PRODUCTION_CERT_SHA256


class IndependentIdentityTests(unittest.TestCase):
    def test_package_and_signer_are_independent(self):
        self.assertEqual(PACKAGE_NAME, 'com.stevenzxs.hermes_android')
        self.assertEqual(PRODUCTION_CERT_SHA256, 'ccc22121cccab1671afaaa432df4a600c8d2c60dd02dc1f0ce3e812200f14d13')
        gradle = pathlib.Path('android/app/build.gradle.kts').read_text()
        self.assertIn('applicationId = "' + PACKAGE_NAME + '"', gradle)

    def test_updates_do_not_use_upstream(self):
        code = pathlib.Path('lib/core/services/app_update_service.dart').read_text(encoding='utf-8')
        self.assertNotIn('rusty4444', code)
        self.assertIn("url.pathSegments[0] != 'stevenzxs'", code)


if __name__ == '__main__':
    unittest.main()
