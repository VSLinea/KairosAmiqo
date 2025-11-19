#!/usr/bin/env python3
"""
RACAG File System Watcher
==========================
Monitors documentation and code directories for changes and triggers
automatic reindexing with debouncing to avoid excessive API calls.

Usage:
    python3 -m racag.watcher.racag_watcher

The watcher monitors:
- /docs/** (all documentation)
- /ios/KairosAmiqo/** (iOS code)
- /android/** (Android code)
- /.github/** (GitHub configs & instructions)
- /infra/** (Infrastructure configs)
"""

import os
import sys
import time
import subprocess
from pathlib import Path
from threading import Timer, Lock
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Debounce settings
DEBOUNCE_SECONDS = 5  # Wait 5 seconds after last change before reindexing
ALLOWED_EXTENSIONS = {".md", ".swift", ".kt", ".py", ".js", ".ts", ".json", ".yaml", ".yml", ".sh"}

# Get repo root
REPO_ROOT = Path(__file__).resolve().parents[2]

# Directories to monitor
WATCH_DIRECTORIES = [
    REPO_ROOT / "docs",
    REPO_ROOT / "ios" / "KairosAmiqo",
    REPO_ROOT / "android",
    REPO_ROOT / ".github",
    REPO_ROOT / "infra",
]


class DebouncedReindexHandler(FileSystemEventHandler):
    """
    Monitors file changes and triggers reindex after debounce period.
    """

    def __init__(self, debounce_seconds: float = 5.0):
        super().__init__()
        self.debounce_seconds = debounce_seconds
        self.timer: Timer | None = None
        self.lock = Lock()
        self.pending_files = set()

    def should_process(self, file_path: str) -> bool:
        """Check if file should trigger reindex."""
        path = Path(file_path)

        # Skip hidden files and directories
        if any(part.startswith(".") for part in path.parts if part not in [".github"]):
            return False

        # Check extension
        if path.suffix.lower() not in ALLOWED_EXTENSIONS:
            return False

        # Skip specific patterns
        skip_patterns = ["__pycache__", "node_modules", ".git", "build", "DerivedData"]
        if any(pattern in file_path for pattern in skip_patterns):
            return False

        return True

    def on_modified(self, event):
        if event.is_directory:
            return

        if not self.should_process(event.src_path):
            return

        with self.lock:
            self.pending_files.add(event.src_path)

            # Cancel existing timer
            if self.timer:
                self.timer.cancel()

            # Start new timer
            self.timer = Timer(self.debounce_seconds, self.trigger_reindex)
            self.timer.start()

            # Log pending change
            rel_path = Path(event.src_path).relative_to(REPO_ROOT)
            print(f"📝 File changed: {rel_path} (reindex in {self.debounce_seconds}s...)")

    def on_created(self, event):
        # Treat new files same as modifications
        self.on_modified(event)

    def on_deleted(self, event):
        # Deletions also require reindex
        self.on_modified(event)

    def trigger_reindex(self):
        """Execute the reindex script."""
        with self.lock:
            file_count = len(self.pending_files)
            self.pending_files.clear()

        print(f"\n🔄 Triggering RACAG reindex ({file_count} files changed)...")
        print("=" * 60)

        try:
            # Run reindex script in incremental mode (not --reset)
            reindex_script = REPO_ROOT / "racag" / "reindex.sh"
            result = subprocess.run(
                [str(reindex_script)],
                cwd=REPO_ROOT,
                capture_output=True,
                text=True,
                timeout=600,  # 10 minute timeout
            )

            if result.returncode == 0:
                print("✅ Reindex complete!")
                # Show summary from output
                for line in result.stdout.split("\n"):
                    if "Chunks indexed:" in line or "Embeddings stored:" in line:
                        print(f"   {line.strip()}")
            else:
                print(f"❌ Reindex failed with code {result.returncode}")
                print(f"Error: {result.stderr}")

        except subprocess.TimeoutExpired:
            print("❌ Reindex timed out (>10 minutes)")
        except Exception as e:
            print(f"❌ Reindex error: {e}")

        print("=" * 60)
        print("👀 Watching for changes...\n")


def main():
    """Start the file watcher."""
    print("🚀 RACAG File System Watcher")
    print("=" * 60)
    print(f"Repository: {REPO_ROOT}")
    print(f"Debounce: {DEBOUNCE_SECONDS} seconds")
    print("\nMonitoring directories:")
    for watch_dir in WATCH_DIRECTORIES:
        if watch_dir.exists():
            print(f"  ✅ {watch_dir.relative_to(REPO_ROOT)}")
        else:
            print(f"  ⚠️  {watch_dir.relative_to(REPO_ROOT)} (not found, skipping)")

    print("\nAllowed extensions:", ", ".join(sorted(ALLOWED_EXTENSIONS)))
    print("=" * 60)
    print("👀 Watching for changes... (Ctrl+C to stop)\n")

    # Create handler and observer
    event_handler = DebouncedReindexHandler(debounce_seconds=DEBOUNCE_SECONDS)
    observer = Observer()

    # Schedule monitoring for each directory
    for watch_dir in WATCH_DIRECTORIES:
        if watch_dir.exists():
            observer.schedule(event_handler, str(watch_dir), recursive=True)

    # Start watching
    observer.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n\n🛑 Stopping watcher...")
        observer.stop()

    observer.join()
    print("👋 Watcher stopped.")


if __name__ == "__main__":
    main()
