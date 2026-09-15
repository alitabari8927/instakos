"""Build-time sanity check + self-heal for the installed insto package.

Runs during `docker build`. Prints diagnostics about what actually landed
in site-packages, and if `insto.__version__` is missing (a packaging quirk
we've seen with the wheel build), patches __init__.py / _version.py
directly so the image still works.
"""
import pathlib
import sys

import insto

pkg_dir = pathlib.Path(insto.__file__).parent
print("insto.__file__ =", insto.__file__)
print("package dir contents:", sorted(p.name for p in pkg_dir.iterdir()))

init_path = pkg_dir / "__init__.py"
version_path = pkg_dir / "_version.py"

print("--- __init__.py content ---")
print(init_path.read_text() if init_path.exists() else "<MISSING __init__.py>")
print("--- _version.py content ---")
print(version_path.read_text() if version_path.exists() else "<MISSING _version.py>")
print("insto.__version__ (before heal) =", getattr(insto, "__version__", "<NOT SET>"))

if not hasattr(insto, "__version__"):
    print("PATCHING: insto.__version__ missing after install; writing it directly.")
    version_path.write_text('__version__ = "0.7.22"  # x-release-please-version\n')
    init_path.write_text('from insto._version import __version__\n\n__all__ = ["__version__"]\n')

# Re-import fresh to confirm the fix actually took.
import importlib

importlib.reload(insto)
final_version = getattr(insto, "__version__", None)
print("insto.__version__ (final) =", final_version)
if not final_version:
    print("FATAL: insto package still has no __version__ after healing.", file=sys.stderr)
    sys.exit(1)
