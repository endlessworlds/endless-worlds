import logging
import os
import time

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware

# ─── Logging Setup ───────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s │ %(levelname)-8s │ %(name)-18s │ %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("EndlessWorlds")

# Load env variables before importing services that use them
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "..", ".env"))

from models.schemas import ScrapeRequest, RAGRequest, RiddleRequest, EvaluateRequest
from services.scraper import search_and_scrape
from services.vectordb import chunk_text, store_in_vectordb, retrieve_docs, has_topic
from services.llm import generate_rag_reply, generate_riddle_json, evaluate_code, groq_client, transcribe_audio

app = FastAPI(title="Endless Worlds RAG API")

# The web build runs in a browser on another origin (GitHub Pages / itch.io).
# ALLOWED_ORIGINS="https://you.github.io,https://html.itch.zone" to lock it down.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in os.getenv("ALLOWED_ORIGINS", "*").split(",")],
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type"],
)

# Endpoints are plain `def` on purpose: scraping, embedding and LLM calls block,
# and FastAPI runs sync endpoints in a thread pool instead of stalling the event loop.


@app.get("/health")
def health():
    return {"status": "ok", "llm": groq_client is not None}


@app.post("/api/scrape")
def scrape_and_store(req: ScrapeRequest):
    """Search the web for the topic, chunk + embed the best page into the topic's own FAISS index."""
    logger.info("POST /api/scrape — Topic: \"%s\"", req.topic)
    start = time.time()
    if has_topic(req.topic):
        logger.info("  ✔ Topic already indexed — reusing cached context")
        return {"status": "success", "url": "cache", "chunks_stored": 0, "cached": True}
    try:
        target_url, cleaned_text = search_and_scrape(req.topic)
        chunks = chunk_text(cleaned_text, chunk_size=500, overlap=50)
        store_in_vectordb(req.topic, chunks)
        logger.info("Scrape pipeline completed in %.2f seconds (%s)", time.time() - start, target_url)
        return {"status": "success", "url": target_url, "chunks_stored": len(chunks), "cached": False}
    except Exception as e:
        logger.error("Scrape pipeline FAILED after %.2f seconds — %s", time.time() - start, str(e))
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/rag")
def rag_query(req: RAGRequest):
    """Answer a prompt using the topic's retrieved context."""
    topic = req.topic or req.prompt
    try:
        reply = generate_rag_reply(req.prompt, retrieve_docs(topic, req.prompt, top_k=3), req.riddle or "")
        return {"reply": reply}
    except Exception as e:
        logger.error("RAG query FAILED — %s", str(e))
        raise HTTPException(status_code=500, detail=str(e))


MAX_AUDIO_BYTES = 4 * 1024 * 1024  # ~2 min of 16 kHz mono PCM


@app.post("/api/transcribe")
async def transcribe(request: Request):
    """Speech-to-text: raw WAV bytes in, {"text": ...} out. Used by the voice bot."""
    body = await request.body()
    if not body or len(body) > MAX_AUDIO_BYTES or body[:4] != b"RIFF":
        raise HTTPException(status_code=400, detail="Send a WAV file under 4 MB")
    try:
        from starlette.concurrency import run_in_threadpool
        return {"text": await run_in_threadpool(transcribe_audio, body)}
    except Exception as e:
        logger.error("Transcription FAILED — %s", str(e))
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/generate_riddle")
def generate_riddle(req: RiddleRequest):
    """Generate a validated riddle JSON from the topic's context (call /api/scrape first)."""
    logger.info("POST /api/generate_riddle — Topic: \"%s\" | Difficulty: \"%s\"", req.topic, req.difficulty)
    start = time.time()
    try:
        docs = retrieve_docs(req.topic, req.topic, top_k=5)
        try:
            result = generate_riddle_json(req.topic, req.difficulty, docs)
        except ValueError as bad:  # LLM broke the answer contract: one retry
            logger.warning("Invalid riddle (%s) — retrying once", bad)
            result = generate_riddle_json(req.topic, req.difficulty, docs)
        logger.info("  ✔ Riddle ready in %.2fs — answer: %s", time.time() - start, result["solution"])
        return result
    except Exception as e:
        logger.error("Riddle generation FAILED after %.2f seconds — %s", time.time() - start, str(e))
        raise HTTPException(status_code=500, detail=f"Failed to generate riddle: {str(e)}")


@app.post("/api/evaluate_code")
def evaluate_code_endpoint(req: EvaluateRequest):
    logger.info("POST /api/evaluate_code — Title: \"%s\"", req.question_title)
    try:
        return evaluate_code(req.question_title, req.question_desc, req.expected_output, req.user_code)
    except Exception as e:
        logger.error("Code evaluation FAILED — %s", str(e))
        raise HTTPException(status_code=500, detail=f"Failed to evaluate code: {str(e)}")


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8000"))
    logger.info("Starting Uvicorn server on http://0.0.0.0:%d", port)
    uvicorn.run(app, host="0.0.0.0", port=port)
