"""File system watchers for automatic reindexing."""

__all__ = ["SwiftWatcherThread"]


def SwiftWatcherThread(*args, **kwargs):
    """Create Swift file watcher thread."""
    from racag.watcher.file_watcher import SwiftWatcherThread as _Watcher
    return _Watcher(*args, **kwargs)
