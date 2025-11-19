import os
import time
import json
import threading
import queue

from racag.watcher.file_watcher import SwiftWatcherThread
from racag.embedding.chunk_embedder import embed_chunk

PROMPTS_DIR = "racag/logs/prompts"
EMBEDDINGS_DIR = "racag/logs/embeddings"
os.makedirs(EMBEDDINGS_DIR, exist_ok=True)


# ---------------------------------------
# INTERNAL QUEUE FOR PIPELINE
# ---------------------------------------
embed_queue = queue.Queue()


# ---------------------------------------
# WORKER: EMBED & SAVE RESULTS
# ---------------------------------------
def embedding_worker():
    print("🧠 [EMBEDDER] Worker online.")

    while True:
        prompt_file = embed_queue.get()
        if prompt_file is None:
            break  # graceful shutdown

        prompt_path = os.path.join(PROMPTS_DIR, prompt_file)

        try:
            with open(prompt_path, "r", encoding="utf-8") as f:
                prompt_data = json.load(f)
        except Exception as e:
            print(f"❌ [EMBEDDER] Failed to read {prompt_path}: {e}")
            continue

        try:
            embedding = embed_chunk(prompt_data)
        except Exception as e:
            print(f"❌ [EMBEDDER] Failed to embed {prompt_file}: {e}")
            continue

        out_name = f"{prompt_data['chunk_id']}.json"
        out_path = os.path.join(EMBEDDINGS_DIR, out_name)

        result = {
            "chunk_id": prompt_data["chunk_id"],
            "embedding": embedding,
            "source_file": prompt_data["source_file"],
            "start_line": prompt_data["start_line"],
            "end_line": prompt_data["end_line"]
        }

        try:
            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(result, f, indent=2)

            print(f"✅ [EMBEDDER] Saved: {out_name}")
        except Exception as e:
            print(f"❌ [EMBEDDER] Failed to save {out_name}: {e}")


# ---------------------------------------
# MAIN PIPELINE LOOP
# ---------------------------------------
def main():
    print("🚀 RACAG Pipeline Starting...")

    # Start watcher thread
    watcher = SwiftWatcherThread(prompts_dir=PROMPTS_DIR)
    watcher.daemon = True
    watcher.start()

    # Start embedding worker
    worker = threading.Thread(target=embedding_worker, daemon=True)
    worker.start()

    print("🔄 RACAG Pipeline running. Watching for new chunks...")

    processed = set()

    try:
        while True:
            for filename in os.listdir(PROMPTS_DIR):
                if not filename.endswith(".json"):
                    continue
                if filename not in processed:
                    processed.add(filename)
                    embed_queue.put(filename)
            time.sleep(1)

    except KeyboardInterrupt:
        print("\n🛑 Shutting down RACAG Pipeline...")

    finally:
        embed_queue.put(None)
        worker.join()


if __name__ == "__main__":
    main()