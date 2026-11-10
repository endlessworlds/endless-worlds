import logging
import os
import threading
import time
from collections import OrderedDict
from typing import List

import faiss
import numpy as np

logger = logging.getLogger("EndlessWorlds.VectorDB")

if os.getenv("DISABLE_SSL_VERIFY") == "1":
    # Opt-in only: lets model downloads work behind proxies/AV that intercept HTTPS.
    import ssl
    os.environ["CURL_CA_BUNDLE"] = ""
    os.environ["REQUESTS_CA_BUNDLE"] = ""
    ssl._create_default_https_context = ssl._create_unverified_context

from sentence_transformers import SentenceTransformer

# ─── Initialise Embedding Model ──────────────────────────────────────────────
logger.info("Loading embedding model: all-MiniLM-L6-v2...")
_load_start = time.time()
try:
    embedder = SentenceTransformer('all-MiniLM-L6-v2')
    logger.info("Embedding model loaded successfully in %.2f seconds", time.time() - _load_start)
except Exception as e:
    logger.error("Failed to load embedding model after %.2f seconds — %s", time.time() - _load_start, str(e))
    embedder = None

VECTOR_DIMENSION = 384
MAX_TOPICS = 64  # LRU cap so a public server can't grow memory without bound

# One FAISS index per topic, so concurrent players never read each other's context.
_stores: "OrderedDict[str, tuple[faiss.IndexFlatL2, List[str]]]" = OrderedDict()
_lock = threading.Lock()


def topic_key(topic: str) -> str:
    return " ".join(topic.lower().split())


def has_topic(topic: str) -> bool:
    with _lock:
        return topic_key(topic) in _stores


def chunk_text(text: str, chunk_size: int = 500, overlap: int = 50) -> List[str]:
    """Splits a long text into smaller chunks with overlap."""
    chunks = []
    start = 0
    while start < len(text):
        end = min(start + chunk_size, len(text))
        chunks.append(text[start:end])
        start += chunk_size - overlap

    logger.info("Text chunked — input: %d chars → %d chunks (size=%d, overlap=%d)",
                len(text), len(chunks), chunk_size, overlap)
    return chunks


def store_in_vectordb(topic: str, chunks: List[str]) -> None:
    """Embeds text chunks into a fresh FAISS index owned by this topic."""
    if not chunks:
        logger.warning("No chunks to store — skipping")
        return
    if not embedder:
        logger.error("Embedder not available — cannot store chunks")
        return

    start = time.time()
    embeddings = embedder.encode(chunks, batch_size=64, show_progress_bar=False)
    index = faiss.IndexFlatL2(VECTOR_DIMENSION)
    index.add(np.array(embeddings, dtype=np.float32))
    logger.info("  ✔ Embedded %d chunks in %.2f seconds", len(chunks), time.time() - start)

    key = topic_key(topic)
    with _lock:
        _stores[key] = (index, list(chunks))
        _stores.move_to_end(key)
        while len(_stores) > MAX_TOPICS:
            _stores.popitem(last=False)


def retrieve_docs(topic: str, query: str, top_k: int = 3) -> List[str]:
    """Retrieves the most similar chunks for a query from the topic's index."""
    with _lock:
        store = _stores.get(topic_key(topic))
    if store is None or not embedder:
        logger.info("Retrieval skipped — no index for topic \"%s\"", topic[:60])
        return []

    index, chunks = store
    query_vector = embedder.encode([query])
    _, indices_arr = index.search(np.array(query_vector, dtype=np.float32), min(top_k, index.ntotal))
    results = [chunks[i] for i in indices_arr[0] if 0 <= i < len(chunks)]
    logger.info("  ✔ Retrieved %d/%d documents", len(results), top_k)
    return results
