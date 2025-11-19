import os
import time
import json
from threading import Thread
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

from racag.chunking.code_chunker import extract_code_chunks
from racag.embedding.prompt_formatter import format_chunk_as_prompt


WATCH_DIRECTORY = "/Users/lyra/KairosMain/ios/KairosAmiqo"


class SwiftFileHandler(FileSystemEventHandler):
    def __init__(self, prompts_dir: str):
        super().__init__()
        self.prompts_dir = prompts_dir
        os.makedirs(prompts_dir, exist_ok=True)

    def on_modified(self, event):
        if event.is_directory or not event.src_path.endswith(".swift"):
            return

        file_path = event.src_path
        print(f"\n📝 Swift file modified: {file_path}")

        try:
            chunks = extract_code_chunks(file_path)
        except Exception as e:
            print(f"❌ Failed to extract chunks from {file_path}: {e}")
            return

        if not chunks:
            print("⚠️ No valid chunks extracted.")
            return

        print(f"✅ Extracted {len(chunks)} chunks:")
        for chunk in chunks:
            chunk_id = chunk.get("chunk_id", "UNKNOWN")
            chunk_lines = chunk.get("lines", "??–??")
            print(f"- {chunk_id} [{chunk_lines}]")

            prompt = format_chunk_as_prompt(chunk)
            chunk["prompt"] = prompt  # embed in JSON

            chunk_name = chunk_id.replace("::", "__")
            prompt_path = os.path.join(self.prompts_dir, f"{chunk_name}.json")

            try:
                with open(prompt_path, "w", encoding="utf-8") as f:
                    json.dump(chunk, f, indent=2)
                print(f"   → Saved prompt: {prompt_path}")
            except Exception as e:
                print(f"❌ Failed to write prompt file: {e}")


class SwiftWatcherThread(Thread):
    def __init__(self, prompts_dir: str):
        super().__init__()
        self.prompts_dir = prompts_dir
        self.event_handler = SwiftFileHandler(prompts_dir)
        self.observer = Observer()

    def run(self):
        try:
            self.observer.schedule(self.event_handler, WATCH_DIRECTORY, recursive=True)
            self.observer.start()
            print(f"👀 SwiftWatcherThread active: {WATCH_DIRECTORY}")
            while True:
                time.sleep(1)
        except Exception as e:
            print(f"❌ Watcher error: {e}")
        finally:
            self.observer.stop()
            self.observer.join()