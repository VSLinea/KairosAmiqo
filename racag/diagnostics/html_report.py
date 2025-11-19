from pathlib import Path
import html
from string import Template

HTML_TEMPLATE = Template("""
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8" />
<title>RACAG Diagnostics</title>
<style>
body { font-family: Arial; margin: 40px; }
h1 { color: #4BC0C0; }
table { border-collapse: collapse; width: 100%; }
th, td { padding: 8px; border-bottom: 1px solid #ddd; }
th { background: #f0f0f0; }
tr:hover { background: #fafafa; }
</style>
</head>
<body>
<h1>RACAG Diagnostics Report</h1>
<p>Total files: $TOTAL</p>

<h2>Extensions</h2>
<table>
<tr><th>Ext</th><th>Count</th></tr>
$EXT_ROWS
</table>

<h2>Files</h2>
<table>
<tr><th>Path</th><th>Ext</th><th>Size</th></tr>
$FILE_ROWS
</table>

</body>
</html>
""")

def write_html_report(results, out_path: Path):
    ext_counts = {}
    for r in results:
        ext_counts[r["ext"]] = ext_counts.get(r["ext"], 0) + 1

    ext_rows = "".join(
        f"<tr><td>{html.escape(ext)}</td><td>{count}</td></tr>"
        for ext, count in sorted(ext_counts.items(), key=lambda x: -x[1])
    )

    file_rows = "".join(
        f"<tr><td>{html.escape(r['path'])}</td><td>{r['ext']}</td><td>{r['size']}</td></tr>"
        for r in results
    )

    html_content = HTML_TEMPLATE.substitute(
        TOTAL=len(results),
        EXT_ROWS=ext_rows,
        FILE_ROWS=file_rows
    )

    out_path.write_text(html_content)
    return out_path
