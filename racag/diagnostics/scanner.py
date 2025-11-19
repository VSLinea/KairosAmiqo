import re
from pathlib import Path

ALLOWED_EXTENSIONS = {
    ".py", ".swift", ".js", ".ts", ".jsx", ".tsx",
    ".java", ".kt", ".sh", ".yaml", ".yml", ".toml",
    ".md", ".markdown", ".txt", ".json", ".ini", ".env"
}

BLOCKED_DIR_NAMES = {
    ".git", ".github", ".idea", ".vscode",
    "node_modules", "Pods", "DerivedData", "build",
    "dist", "out", "target",
    "__pycache__", ".DS_Store", ".venv", "venv",
    "racag_env", "env"
}

SKIP_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".heic", ".gif",
    ".svg", ".pdf", ".mp4", ".mov", ".avi",
    ".zip", ".tar", ".gz", ".so", ".dylib", ".bin",
    ".xcworkspace", ".xcodeproj"
}

def is_binary_file(path: Path) -> bool:
    try:
        with open(path, "rb") as f:
            return b"\0" in f.read(4000)
    except:
        return True

def should_skip_dir(path: Path) -> bool:
    return any(part in BLOCKED_DIR_NAMES for part in path.parts)

def should_skip_file(path: Path) -> bool:
    if path.suffix.lower() in SKIP_EXTENSIONS:
        return True
    if is_binary_file(path):
        return True
    return False

def scan_repo(repo_root: Path):
    results = []
    for p in repo_root.rglob("*"):
        if p.is_dir() and should_skip_dir(p):
            continue
        if not p.is_file():
            continue
        if should_skip_file(p):
            continue

        ext = p.suffix.lower()
        results.append({
            "path": str(p),
            "ext": ext,
            "is_code": ext in {".py", ".swift", ".js", ".ts", ".jsx", ".tsx", ".java", ".kt"},
            "is_markdown": ext in {".md", ".markdown", ".txt"},
            "is_json": ext == ".json",
            "size": p.stat().st_size
        })
    return results
