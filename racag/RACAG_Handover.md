
# RACAG / CAG Engine — Handover (A → Z)

This document explains **what the engine does**, **where it lives in the repo**, the **end‑to‑end data flow**, **key files**, and **how to run / troubleshoot**. It’s written to let you keep building inside VS Code without context loss.

---

## 1) Purpose (What it does)

**RACAG = Retrieval‑Augmented, Context‑Aware Generator** for your Kairos codebase.

It:
1. **Scans** your repo and **chunks** source & docs into atomic units.
2. **Embeds** the chunks and stores them in a **local ChromaDB** (SQLite on disk).
3. **Answers queries** by:
   - Embedding the question
   - Retrieving similar chunks from Chroma
   - **Reranking** with cosine + a lightweight GPT model
   - Returning a **clean, minimal context** payload (ids, file paths, line ranges, text)
4. (Optional) **Serves an API** for tools (Copilot, backend, iOS, Node‑RED).

---

## 2) Where it lives (Repo layout)

Top‑level project (only showing RACAG‑relevant paths):

```
racag/
  adapters/
    backend_adapter.py
    copilot_adapter.py
  api/
    api.py
    copilot_adapter.py
    run_api.py
    server.py
  chunking/
    code_chunker.py
    json_chunker.py
    markdown_chunker.py
    normalize.py
    run_chunkers.py
  context/
    context_assembler.py
  db/
    chroma_store/           # ← Chroma SQLite lives here (e.g., chroma.sqlite3)
  diagnostics/
    charts.py
    html_report.py
    json_report.py
    run_diagnostics.py
    output/
      report.html
      report.json
  embedding/
    embed_all.py            # ← main batch embedder (reads chunks.jsonl → Chroma)
    embedder.py
    chunk_embedder.py
    embed_chunks.py
    prompt_formatter.py
  logs/
    embeddings/             # per‑chunk embed logs (optional)
    prompts/                # captured prompts (optional)
    racag.log               # engine logs
  output/
    chunks.jsonl            # ← chunking output (input to embedding)
    errors.jsonl            # ← chunking errors
    meta_summary.json       # ← counts per type/dir/lang
  query/
    __init__.py
    query_engine.py         # ← main orchestrator (embed → retrieve → rerank → format)
  reranker/
    model_loader.py         # ← OpenAI clients, embed ops, LLM scoring
    similarity.py           # cosine helpers
    rerank_engine.py        # hybrid (cosine + LLM) reranking
  retrieval/
    query_embedder.py
    semantic_retriever.py
  runtime/
    racag_runtime.py
  server/
    fastapi_server.py       # optional HTTP API
  telemetry/
    noop_tracing.py         # forces no‑op tracing if needed
  test_cli.py               # ← “smoke test” CLI: asks questions against the DB
  run.py
  run_pipeline.py
```

---

## 3) End‑to‑end data flow

```
[Your repo files]
      │
      │  (1) Chunkers walk the tree
      ▼
[racag/output/chunks.jsonl]  +  errors.jsonl  +  meta_summary.json
      │
      │  (2) Embed stage (OpenAI embeddings, batched)
      ▼
[racag/db/chroma_store]  (Chroma persistent SQLite: chroma.sqlite3)
      │
      │  (3) Query (embed question)
      ▼
[Chroma top‑K retrieve (cosine)]
      │
      │  (4) Rerank (cosine + GPT‑4.1‑mini score)
      ▼
[Final minimal context]
      │
      └─▶ CLI / API / Copilot adapters
```

### 3.1 Chunking stage

**Input:** your working tree (minus exclusions set in `run_chunkers.py`)  
**Output:** `racag/output/chunks.jsonl` — one JSON object per line (**chunk**).

**Chunk schema (normalized):**
```json
{
  "chunk_id": "file::stable_hash",
  "chunk_text": "source snippet …",
  "language": "swift|python|json|markdown|…",
  "file_path": "/abs/path/to/file",
  "module": "inferred/module/or/dir",
  "function": "function_or_struct_if_detected",
  "framework": "swift|node|…",
  "tags": ["any","labels"],            // normalized → comma string for Chroma
  "start_line": 123,
  "end_line": 141,
  "lines": "123-141"                   // pre‑formatted summary
}
```

**Side outputs:**
- `racag/output/errors.jsonl` — files we couldn’t parse (encoding, corrupt, etc.)  
- `racag/output/meta_summary.json` — counts by type, language, directory

### 3.2 Embedding stage

**File:** `racag/embedding/embed_all.py`  
**What it does:**
- Reads `chunks.jsonl` in **batches** (default **32**).
- **Embeds** with OpenAI **`text-embedding-3-large`** (via `reranker/model_loader.py`).
- Writes to **Chroma persistent** collection **`kairos_chunks`** at `racag/db/chroma_store/`.
- Ensures **metadata types** fit Chroma’s rules (str/int/float/bool), flattens lists (e.g., `tags` → comma string).
- Enforces **stable unique IDs**: `f"{file_path}::{chunk_id}"` to avoid duplicates.

**Chroma record shape (conceptual):**
```json
{
  "id": "…",
  "embedding": [0.001, 0.012, …],
  "document": "chunk_text",
  "metadata": {
    "file_path": "/abs/path.swift",
    "language": "swift",
    "lines": "10-28",
    "module": "…",
    "function": "…",
    "tags": "a,b,c",
    "framework": "swiftui"
  }
}
```

### 3.3 Query & Rerank stage

**Entry point:** `racag/query/query_engine.py`

Steps:
1. **Embed query** → vector (same embedding model as chunks).  
2. **Retrieve** from Chroma with cosine, top‑K (**default 40**).  
3. **Rerank** with hybrid score:
   - **Cosine** (candidate vs. query)
   - **LLM score** using **`gpt-4.1-mini`** (fast, cheap scalar relevance)
   - **Hybrid** = weighted combination (see `reranker/rerank_engine.py`)
4. **Format** minimal context for tools (Copilot, API).

**Query output shape:**
```json
{
  "query": "Where is DashboardView built?",
  "status": "success",
  "count": 3,
  "results": [
    {
      "id": "/abs/file.swift::abcd1234",
      "score_hybrid": 0.91,
      "score_cosine": 0.83,
      "score_llm": 0.95,
      "file": "/abs/file.swift",
      "lang": "swift",
      "lines": "210-268",
      "text": "struct DashboardView: View { … }"
    }
  ]
}
```

Reranker internals:
- **Cosine** helpers in `reranker/similarity.py`
- **LLM scoring** & **embedding client** in `reranker/model_loader.py`
- **Hybrid orchestration** in `reranker/rerank_engine.py`

---

## 4) How to run (step‑by‑step)

> Assumes Python **3.11**, venv active, and `OPENAI_API_KEY` exported.

### 4.1 Chunk the repo

```bash
cd ~/KairosMain
source racag_env/bin/activate
python -m racag.chunking.run_chunkers
# outputs to: racag/output/{chunks.jsonl, errors.jsonl, meta_summary.json}
```

### 4.2 Embed all chunks → Chroma

```bash
export OPENAI_API_KEY=sk-…
python -m racag.embedding.embed_all
# persists to: racag/db/chroma_store/chroma.sqlite3
```

### 4.3 Ask a question (CLI smoke test)

```bash
python -m racag.test_cli "Where is DashboardView built?"
```

### 4.4 (Optional) Start the API

```bash
python -m racag.server.fastapi_server
# then POST /query with {"query":"…"} to get the same payload as CLI
```

---

## 5) Data elements passed stage‑to‑stage

| Stage | Input → Output | Key names carried forward |
|---|---|---|
| **Chunking** | files → `chunks.jsonl` | `chunk_id`, `chunk_text`, `file_path`, `language`, `module`, `function`, `framework`, `tags`, `start_line`, `end_line`, `lines` |
| **Embedding** | `chunks.jsonl` → Chroma records | `id` = `file_path::chunk_id`, `document`=`chunk_text`, `metadata` (flattened, str/bool/number), `embedding` |
| **Query** | user query → vector → Chroma query → candidates | `id`, `chunk_text` (as `document`), `metadata`, `embedding` |
| **Rerank** | candidates + `query_vec` | adds `cosine`, `llm_score`, `hybrid` |
| **Final** | top‑K | returns `id`, `score_hybrid`, `score_cosine`, `score_llm`, `file`, `lang`, `lines`, `text` |

---

## 6) Config you will touch most

- **`racag/query/query_engine.py`**
  - `RETRIEVE_K = 40` (pre‑rerank set size)
  - `FINAL_K = 3` (return size; can expand to 5 or 8 if needed)
  - `CHROMA_PATH`, `COLL_NAME`

- **`racag/reranker/model_loader.py`**
  - `text-embedding-3-large` for embeddings
  - `gpt-4.1-mini` for LLM scoring
  - All OpenAI client setup (`OPENAI_API_KEY` required)

- **`racag/chunking/run_chunkers.py`**
  - Repo walk, **exclusions**, per‑language chunkers, JSONL output

- **`racag/diagnostics/run_diagnostics.py`** (optional)
  - Scans & produces HTML/JSON reports of what would be chunked

---

## 7) Troubleshooting (what bit us & fixes)

- **Import drifts / symbol mismatches**
  - `racag/query/__init__.py` exports **only** `QueryEngine` now
  - `query_engine.py` provides **class `QueryEngine`** + legacy `query_engine()`

- **Chroma metadata type errors**
  - Ensure metadata values are `str | int | float | bool` (flatten lists like `tags`)

- **Duplicate IDs**
  - Use stable scheme `id = f"{file_path}::{chunk_id}"`

- **OpenAI client ‘proxies’ error**
  - Pin working HTTP stack: `httpx==0.27.2`, `httpcore==1.0.5`

- **Telemetry / opentelemetry noise**
  - We run with `Settings(anonymized_telemetry=False)` and a **no‑op tracer** if needed

- **Chroma / hnswlib compat**
  - Use the **working pair** you validated locally (your current setup); avoid mixing versions mid‑run.

---

## 8) Minimal code contracts (what callers rely on)

- **CLI** (`racag/test_cli.py`):
  ```python
  from racag.query import QueryEngine
  engine = QueryEngine()
  print(engine.run("question"))
  ```

- **Query return contract** (stable surface for adapters):
  ```json
  {
    "query": "…",
    "status": "success|no_results|error",
    "count": 3,
    "results": [
      { "id": "…", "score_hybrid": 0.91, "score_cosine": 0.83, "score_llm": 0.95,
        "file": "/abs/path.swift", "lang": "swift", "lines": "10-28", "text": "…" }
    ]
  }
  ```

---

## 9) Handover checklist

- [ ] `racag/output/chunks.jsonl` present and sane (size looks right)
- [ ] `racag/db/chroma_store/chroma.sqlite3` exists after embedding
- [ ] `OPENAI_API_KEY` exported
- [ ] `python -m racag.test_cli "…" ` returns a JSON dict with `results`
- [ ] (Optional) API starts and answers `POST /query`

If anything regresses, start with the **CLI** (fastest signal), then inspect
- `racag/output/chunks.jsonl` (is it empty? malformed?)
- Chroma collection exists? (try a quick `col.count()` in a REPL)
- Engine logs: `racag/logs/racag.log`


— **RACAG handover complete.**
