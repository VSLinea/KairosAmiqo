import sys
from chromadb import PersistentClient
from openai import OpenAI
import os

# Load OpenAI key
openai_client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# Init ChromaDB client
chroma_client = PersistentClient(path="racag/db/chroma_store")
collection = chroma_client.get_or_create_collection(name="kairos_chunks")

def embed_query(query: str):
    """Embed the search query"""
    response = openai_client.embeddings.create(
        model="text-embedding-3-small",
        input=query
    )
    return response.data[0].embedding

def search(query: str, top_k: int = 3):
    """Query ChromaDB and return top-k results"""
    query_vector = embed_query(query)
    results = collection.query(
        query_embeddings=[query_vector],
        n_results=top_k
    )

    docs = results["documents"][0]
    metadata = results["metadatas"][0]

    for i, doc in enumerate(docs):
        print(f"\n🔹 Match {i+1}:")
        print(f"📄 File: {metadata[i]['file']} ({metadata[i]['lines']})")
        print(f"🧠 Chunk ID: {metadata[i]['chunk_id']}")
        print("📜 Text:\n" + doc.strip())

if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[1] != "--query":
        print("Usage: python main.py --query \"your search text here\"")
    else:
        query = " ".join(sys.argv[2:])
        search(query)