"""Attach requested entitlements without an Apple certificate or private key.

The resulting ad-hoc signature is metadata for the Windows re-signer. It is NOT
an Apple development/ad-hoc distribution signature and cannot install on iOS.
"""
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path

from verify_dev_build import APP, GROUP


def run(*args):
    subprocess.run(args, check=True)


def seal(app):
    extension = app / "PlugIns/Keyboard.appex"
    for bundle, identifier in ((app, APP), (extension, APP + ".keyboard")):
        assert plistlib.loads((bundle / "Info.plist").read_bytes())["CFBundleIdentifier"] == identifier
    with tempfile.TemporaryDirectory() as temporary:
        entitlements = Path(temporary) / "Dev.entitlements"
        expected = {"com.apple.security.application-groups": [GROUP]}
        entitlements.write_bytes(plistlib.dumps(expected))
        dependencies = list(app.rglob("*.framework")) + list(app.rglob("*.dylib"))
        for dependency in sorted(dependencies, key=lambda p: len(p.parts), reverse=True):
            run("codesign", "--force", "--sign", "-", str(dependency))
        for bundle in (extension, app):
            run("codesign", "--force", "--sign", "-", "--entitlements", str(entitlements), str(bundle))
            actual = subprocess.check_output(
                ["codesign", "--display", "--entitlements", "-", str(bundle)], stderr=subprocess.DEVNULL
            )
            assert plistlib.loads(actual) == expected, "Entitlements were not preserved"
        run("codesign", "--verify", "--deep", "--strict", str(app))
    print("Certificate-free metadata signatures verified; Windows re-signing is still required")


if __name__ == "__main__":
    seal(Path(sys.argv[1]))
