import json
from pathlib import Path

def write_json_report(results, out_path: Path):
    data = {
        "total_files": len(results),
        "by_extension": {},
        "files": results
    }
    for item in results:
        ext = item["ext"]
        data["by_extension"].setdefault(ext, 0)
        data["by_extension"][ext] += 1

    out_path.write_text(json.dumps(data, indent=2))
    return out_path
