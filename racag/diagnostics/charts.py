from pathlib import Path
import matplotlib.pyplot as plt
from collections import Counter

def make_charts(results, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)

    exts = [r["ext"] for r in results]
    counter = Counter(exts)

    plt.figure(figsize=(12, 6))
    plt.bar(counter.keys(), counter.values())
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(out_dir / "extensions_bar.png")
    plt.close()

    plt.figure(figsize=(10, 10))
    plt.pie(counter.values(), labels=counter.keys(), autopct='%1.1f%%')
    plt.savefig(out_dir / "extensions_pie.png")
    plt.close()

    return out_dir
