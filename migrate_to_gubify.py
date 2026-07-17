
#!/usr/bin/env python3
"""
Gubify Migration Tool (starter)

This script performs the safe, first-stage migration:
- Creates a backup of the project
- Renames Hubfy -> Gubify in text files
- Renames hubfy -> gubify in text files
- Renames common Dart filenames containing "hub"
- Skips build/.git/.dart_tool/etc.

Review changes with git before committing.
"""

from pathlib import Path
import shutil

SKIP_DIRS = {
    ".git", ".dart_tool", "build", ".idea",
    "ios/Pods", "android/.gradle"
}

TEXT_EXTENSIONS = {
    ".dart",".yaml",".yml",".json",".xml",".gradle",".kts",
    ".plist",".swift",".kt",".java",".md",".txt",".html",
    ".css",".js",".properties",".pbxproj",".xcconfig"
}

REPLACEMENTS = [
    ("Hubfy","Gubify"),
    ("hubfy","gubify"),
    ("com.hubfy.app","com.gubify.app"),
]

FILE_RENAMES = {
    "hub_screen.dart":"gub_screen.dart",
    "hub_service.dart":"gub_service.dart",
    "hub_repository.dart":"gub_repository.dart",
    "hub_model.dart":"gub_model.dart",
}

def should_skip(path: Path):
    s = str(path).replace("\\","/")
    return any(part in s for part in [".git/",".dart_tool/","build/","ios/Pods/","android/.gradle/"])

root = Path.cwd()

backup = root.parent / f"{root.name}_backup_before_gubify"
if not backup.exists():
    print(f"Creating backup: {backup}")
    shutil.copytree(root, backup, ignore=shutil.ignore_patterns(".git","build",".dart_tool","Pods"))

changed = 0

for p in root.rglob("*"):
    if p.is_dir() or should_skip(p):
        continue

    if p.suffix.lower() in TEXT_EXTENSIONS:
        try:
            text = p.read_text(encoding="utf-8")
        except Exception:
            continue
        original = text
        for old,new in REPLACEMENTS:
            text = text.replace(old,new)
        if text != original:
            p.write_text(text, encoding="utf-8")
            changed += 1
            print("Updated:", p)

for p in sorted(root.rglob("*"), reverse=True):
    if p.is_file() and p.name in FILE_RENAMES:
        new = p.with_name(FILE_RENAMES[p.name])
        if not new.exists():
            p.rename(new)
            print("Renamed:", p.name, "->", new.name)

print(f"\nDone. Text files updated: {changed}")
print("Review with git diff before committing.")
