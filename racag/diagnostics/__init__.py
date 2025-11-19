"""Repository diagnostics and analysis tools."""

__all__ = ["scan_repo", "write_json_report", "write_html_report"]


def scan_repo(repo_path: str):
    """Scan repository for code patterns."""
    from racag.diagnostics.scanner import scan_repo as _scan
    return _scan(repo_path)


def write_json_report(data: dict, output_path: str):
    """Write diagnostic report as JSON."""
    from racag.diagnostics.json_report import write_json_report as _write
    return _write(data, output_path)


def write_html_report(data: dict, output_path: str):
    """Write diagnostic report as HTML."""
    from racag.diagnostics.html_report import write_html_report as _write
    return _write(data, output_path)
