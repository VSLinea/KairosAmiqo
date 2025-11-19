import sys
from pathlib import Path

from racag.diagnostics.scanner import scan_repo
from racag.diagnostics.json_report import write_json_report
from racag.diagnostics.html_report import write_html_report

def main():
    repo = Path(__file__).resolve().parents[2]
    out_dir = repo / "racag" / "diagnostics" / "output"
    out_dir.mkdir(parents=True, exist_ok=True)

    if len(sys.argv) < 2:
        print("Usage: python -m racag.diagnostics.run_diagnostics [dry|json|html|all]")
        return

    mode = sys.argv[1]
    print("Scanning repository...")
    results = scan_repo(repo)
    print("Found", len(results), "files")

    if mode in ("dry", "all"):
        print("Dry run complete.")

    if mode in ("json", "all"):
        write_json_report(results, out_dir / "report.json")

    if mode in ("html", "all"):
        write_html_report(results, out_dir / "report.html")

    print("Diagnostics complete.")

if __name__ == "__main__":
    main()
