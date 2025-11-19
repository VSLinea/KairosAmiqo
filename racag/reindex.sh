#!/bin/bash
#
# RACAG Full Reindex Script
# ==========================
# Rechunks + reembeds the entire KairosMain codebase
# Use this after major documentation reorganization or file moves
#
# Usage:
#   ./reindex.sh          # Incremental (add new chunks only)
#   ./reindex.sh --reset  # Full reset (drop existing embeddings)
#

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT"

# Activate virtual environment if it exists
if [ -d "racag_env" ]; then
    echo "🐍 Activating racag_env..."
    source racag_env/bin/activate
fi

# Load OpenAI API key from .copilot/.secrets
if [ -f ".copilot/.secrets" ]; then
    export OPENAI_API_KEY=$(cat .copilot/.secrets)
    echo "🔑 OpenAI API key loaded"
else
    echo "❌ Error: .copilot/.secrets not found!"
    exit 1
fi

echo "🔄 RACAG Full Reindex Pipeline"
echo "================================"
echo "Repo: $REPO_ROOT"
echo ""

# Step 1: Rechunk
echo "1️⃣ Phase 1: Rechunking..."
echo "   Scanning: /ios, /android, /docs, /infra, /.github"
python3 -m racag.chunking.run_chunkers
if [ $? -ne 0 ]; then
    echo "❌ Chunking failed!"
    exit 1
fi
echo "✅ Chunking complete"
echo ""

# Step 2: Reembed
echo "2️⃣ Phase 2: Reembedding..."
if [ "$1" == "--reset" ]; then
    echo "   Mode: FULL RESET (dropping existing embeddings)"
    python3 -m racag.embedding.embed_all --reset
else
    echo "   Mode: INCREMENTAL (adding new chunks only)"
    python3 -m racag.embedding.embed_all
fi

if [ $? -ne 0 ]; then
    echo "❌ Embedding failed!"
    exit 1
fi
echo "✅ Embedding complete"
echo ""

# Step 3: Verify
echo "3️⃣ Phase 3: Verification..."
CHUNK_COUNT=$(wc -l < racag/output/chunks.jsonl | xargs)
echo "   Chunks indexed: $CHUNK_COUNT"

# Query DB to get embedding count
DB_COUNT=$(python3 -c "from chromadb import PersistentClient; c = PersistentClient(path='racag/db/chroma_store'); print(c.get_or_create_collection('kairos_chunks').count())")
echo "   Embeddings stored: $DB_COUNT"

if [ "$CHUNK_COUNT" -eq "$DB_COUNT" ]; then
    echo "✅ Verification passed (counts match)"
else
    echo "⚠️  Warning: Chunk count ($CHUNK_COUNT) != embedding count ($DB_COUNT)"
    echo "   This is OK if you ran incremental mode on an existing DB"
fi
echo ""

echo "🎉 RACAG reindex complete!"
echo ""
echo "Next steps:"
echo "  • Test query: python3 -m racag \"active TestFlight documentation\""
echo "  • Start watcher: VS Code task 'RACAG: Start Watcher'"
echo "  • Check output: racag/output/meta_summary.json"
