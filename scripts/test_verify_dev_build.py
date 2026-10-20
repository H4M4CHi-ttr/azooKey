import copy
import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path

from verify_dev_build import APP, GROUP, verify_ipa, verify_source


class DevBuildTests(unittest.TestCase):
    def fixture(self, app_id=APP, extension=True, signed=False):
        main = {
            "CFBundleIdentifier": app_id, "CFBundleDisplayName": "azooKey Dev",
            "CFBundleExecutable": "azooKey", "AzooKeyAppGroup": GROUP,
            "CFBundleURLTypes": [{"CFBundleURLSchemes": ["azooKeyDev"]}]
        }
        keyboard = copy.deepcopy(main)
        keyboard.update({"CFBundleIdentifier": app_id + ".keyboard", "CFBundleExecutable": "Keyboard",
                         "NSExtension": {"NSExtensionPointIdentifier": "com.apple.keyboard-service"}})
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        path = Path(temporary.name) / "test.ipa"
        with zipfile.ZipFile(path, "w") as archive:
            prefix = "Payload/azooKey.app/"
            archive.writestr(prefix + "Info.plist", plistlib.dumps(main))
            archive.writestr(prefix + "azooKey", b"test-executable")
            if extension:
                archive.writestr(prefix + "PlugIns/Keyboard.appex/Info.plist", plistlib.dumps(keyboard))
                archive.writestr(prefix + "PlugIns/Keyboard.appex/Keyboard", b"test-executable")
            if signed:
                archive.writestr(prefix + "_CodeSignature/CodeResources", b"metadata")
        return path

    def test_source_has_no_production_identity(self):
        verify_source()

    def test_valid_unsigned_package(self):
        verify_ipa(self.fixture())

    def test_production_bundle_is_rejected(self):
        with self.assertRaises(AssertionError):
            verify_ipa(self.fixture(app_id="DevEn3.azooKey"))

    def test_missing_extension_is_rejected(self):
        with self.assertRaises(KeyError):
            verify_ipa(self.fixture(extension=False))

    def test_metadata_signatures_are_explicit(self):
        package = self.fixture(signed=True)
        with self.assertRaises(AssertionError):
            verify_ipa(package)
        verify_ipa(package, allow_adhoc=True)


if __name__ == "__main__":
    unittest.main()
