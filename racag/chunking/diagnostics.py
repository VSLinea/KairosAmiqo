import statistics
from collections import Counter, defaultdict
from typing import List, Dict


def run_diagnostics(raw_chunks: List[Dict], normalized_chunks: List[Dict]):
    """
    Generate a structured diagnostics report for the RACAG ingestion pipeline.
    """
    print("\n")
    print("===============================================")
    print(" 🔎 RACAG INGESTION DIAGNOSTICS")
    print("===============================================")

    # ------------------------------
    # 1. BASIC COUNTS
    # ------------------------------
    print(f"📂 Raw chunks:        {len(raw_chunks)}")
    print(f"🧹 Normalized chunks: {len(normalized_chunks)}")

    # ------------------------------
    # 2. MISSING FIELDS
    # ------------------------------
    required_fields = {"chunk_id", "chunk_text", "file_path",
                       "language", "framework", "function",
                       "module", "start_line", "end_line"}

    missing_field_counts = Counter()

    for c in normalized_chunks:
        for f in required_fields:
            if f not in c or c[f] in ("", None):
                missing_field_counts[f] += 1

    if sum(missing_field_counts.values()) == 0:
        print("🟢 All chunks contain complete metadata.")
    else:
        print("🟡 Missing metadata:")
        for f, n in missing_field_counts.items():
            if n > 0:
                print(f"   - {f}: missing in {n} chunks")

    # ------------------------------
    # 3. CHUNK LENGTH STATS
    # ------------------------------
    lengths = [len(c["chunk_text"]) for c in normalized_chunks]
    print(f"\n✂️ Chunk length stats:")
    print(f"   - Min:     {min(lengths)} chars")
    print(f"   - Max:     {max(lengths)} chars")
    print(f"   - Mean:    {int(statistics.mean(lengths))} chars")
    print(f"   - Median:  {int(statistics.median(lengths))} chars")

    # Bucket distribution
    buckets = defaultdict(int)
    for l in lengths:
        if l < 200:
            buckets["0–200"] += 1
        elif l < 500:
            buckets["200–500"] += 1
        elif l < 1000:
            buckets["500–1000"] += 1
        elif l < 2000:
            buckets["1000–2000"] += 1
        else:
            buckets["2000+"] += 1

    print("\n📊 Chunk size distribution:")
    for bucket, count in buckets.items():
        print(f"   - {bucket}: {count}")

    # ------------------------------
    # 4. LANGUAGE & FRAMEWORK COVERAGE
    # ------------------------------
    lang_count = Counter(c["language"] for c in normalized_chunks)
    fw_count = Counter(c["framework"] for c in normalized_chunks)

    print("\n🧠 Language coverage:")
    for lang, n in lang_count.most_common():
        print(f"   - {lang}: {n}")

    print("\n🧱 Framework coverage:")
    for fw, n in fw_count.most_common():
        print(f"   - {fw}: {n}")

    # ------------------------------
    # 5. FILE CONTRIBUTION STATS
    # ------------------------------
    file_sizes = Counter(c["file_path"] for c in normalized_chunks)

    print("\n📌 Top 10 files by chunk count:")
    for fp, n in file_sizes.most_common(10):
        print(f"   - {fp}: {n} chunks")

    print("\n===============================================")
    print(" 🟢 Diagnostics complete.")
    print("===============================================")