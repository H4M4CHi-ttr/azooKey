"""Fail before distributing an IPA that could be confused with production."""
import argparse
import json
import plistlib
import re
import struct
import zipfile
from pathlib import Path

APP = "io.github.h4m4chi-ttr.azookey.dev.a159b2"
GROUP = "group." + APP
ROOT = Path(__file__).resolve().parents[1]


def verify_source():
    config = (ROOT / "Config/Dev.xcconfig").read_text(encoding="utf-8")
    assert f"AZOOKEY_APP_BUNDLE_ID = {APP}" in config
    identity = (ROOT / "AzooKeyCore/Sources/KeyboardExtensionUtils/DevAppIdentity.swift").read_text(encoding="utf-8")
    assert f'baseGroup = "{GROUP}"' in identity
    icon = (ROOT / "MainApp/Assets.xcassets/AppIconDev.appiconset/DevIcon.png").read_bytes()
    assert struct.unpack(">II", icon[16:24]) == (1024, 1024)
    project = (ROOT / "azooKey.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    assert "PRODUCT_BUNDLE_IDENTIFIER = DevEn3." not in project
    assert project.count("baseConfigurationReference = A159B2000000000000000001") == 2
    for relative in ("MainApp/azooKey.entitlements", "Keyboard/Keyboard.entitlements"):
        entitlements = plistlib.loads((ROOT / relative).read_bytes())
        assert entitlements == {"com.apple.security.application-groups": ["$(AZOOKEY_APP_GROUP)"]}
    for folder in ("MainApp", "Keyboard"):
        info = plistlib.loads((ROOT / folder / "Info.plist").read_bytes())
        assert info["CFBundleDisplayName"] == "$(AZOOKEY_DISPLAY_NAME)"
    main = plistlib.loads((ROOT / "MainApp/Info.plist").read_bytes())
    assert main["CFBundleURLTypes"][0]["CFBundleURLSchemes"] == ["$(AZOOKEY_URL_SCHEME)"]
    assert "CFBundleDocumentTypes" not in main and "UTExportedTypeDeclarations" not in main
    strings = json.loads((ROOT / "Resources/InfoPlist.xcstrings").read_text(encoding="utf-8"))
    assert strings["strings"]["CFBundleDisplayName"]["localizations"]["ja"]["stringUnit"]["value"] == "azooKey Dev"
    for directory in ("MainApp", "Keyboard", "AzooKeyCore/Sources"):
        for path in (ROOT / directory).rglob("*.swift"):
            source = path.read_text(encoding="utf-8")
            assert "group.com.azooKey.keyboard" not in source, path
            assert '"DevEn3.azooKey.keyboard"' not in source, path
            # Historical release notes are text, not navigation.
            if path.name != "UpdateHistoryView.swift":
                assert "azooKey://" not in source, path


def verify_ipa(path, allow_adhoc=False):
    with zipfile.ZipFile(path) as archive:
        apps = [name for name in archive.namelist() if re.fullmatch(r"Payload/[^/]+\.app/Info.plist", name)]
        assert len(apps) == 1, "IPA must contain exactly one app"
        prefix = apps[0].removesuffix("Info.plist")
        main = plistlib.loads(archive.read(apps[0]))
        keyboard = plistlib.loads(archive.read(prefix + "PlugIns/Keyboard.appex/Info.plist"))
        assert main["CFBundleIdentifier"] == APP
        assert keyboard["CFBundleIdentifier"] == APP + ".keyboard"
        assert main["CFBundleDisplayName"] == keyboard["CFBundleDisplayName"] == "azooKey Dev"
        assert main["CFBundleURLTypes"][0]["CFBundleURLSchemes"] == ["azooKeyDev"]
        assert main["AzooKeyAppGroup"] == keyboard["AzooKeyAppGroup"] == GROUP
        assert keyboard["NSExtension"]["NSExtensionPointIdentifier"] == "com.apple.keyboard-service"
        assert archive.read(prefix + main["CFBundleExecutable"]), "Missing app executable"
        assert archive.read(prefix + "PlugIns/Keyboard.appex/" + keyboard["CFBundleExecutable"]), "Missing keyboard executable"
        assert not any(name.endswith("embedded.mobileprovision") for name in archive.namelist())
        if not allow_adhoc:
            assert not any("_CodeSignature/" in name for name in archive.namelist())
        for info in (main, keyboard):
            assert not any("$(" in str(value) for value in info.values()), "Unexpanded build setting"


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--ipa", type=Path)
    parser.add_argument("--allow-adhoc", action="store_true")
    args = parser.parse_args()
    verify_source()
    if args.ipa:
        verify_ipa(args.ipa, allow_adhoc=args.allow_adhoc)
    print("Development identity checks passed" + (" (source and IPA)" if args.ipa else " (source)"))
