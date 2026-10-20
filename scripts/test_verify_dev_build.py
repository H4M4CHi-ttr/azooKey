import copy
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

from verify_dev_build import APP, GROUP, verify_ipa, verify_source
from prepare_resign_ipa import seal


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

    @unittest.skipUnless(sys.platform == "darwin", "Native codesign check requires macOS")
    def test_certificate_free_entitlements_roundtrip(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / "azooKey.app"
            extension = app / "PlugIns/Keyboard.appex"
            extension.mkdir(parents=True)
            sdk = subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"], text=True).strip()
            subprocess.run(
                ["xcrun", "--sdk", "iphoneos", "clang", "-target", "arm64-apple-ios17.6", "-isysroot", sdk,
                 "-x", "c", "-o", str(app / "azooKey"), "-"],
                input=b"int main(void) { return 0; }\n", check=True, capture_output=True
            )
            shutil.copyfile(app / "azooKey", extension / "Keyboard")
            for bundle, identifier, executable, kind in (
                (app, APP, "azooKey", "APPL"), (extension, APP + ".keyboard", "Keyboard", "XPC!")
            ):
                (bundle / "Info.plist").write_bytes(plistlib.dumps({
                    "CFBundleIdentifier": identifier, "CFBundleExecutable": executable,
                    "CFBundlePackageType": kind, "CFBundleVersion": "1"
                }))
            seal(app)


if __name__ == "__main__":
    unittest.main()
