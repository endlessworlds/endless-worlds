import logging
import os
import json
import random
import re
import time
from groq import Groq
from typing import List
import httpx

logger = logging.getLogger("EndlessWorlds.LLM")

GROQ_API_KEY = os.getenv("GROQ_API_KEY")

# DISABLE_SSL_VERIFY=1 works around proxies/AV that intercept HTTPS (local dev only).
_http_client = httpx.Client(verify=os.getenv("DISABLE_SSL_VERIFY") != "1", timeout=60)

if GROQ_API_KEY:
    groq_client = Groq(api_key=GROQ_API_KEY, http_client=_http_client)
    logger.info("Groq client initialised — API key loaded (model: openai/gpt-oss-120b)")
else:
    groq_client = None
    logger.warning("Groq client NOT initialised — GROQ_API_KEY is missing from environment")

# ─── Context limits ──────────────────────────────────────────────────────────
# Capping context avoids sending huge scraped pages to the LLM, which burns
# tokens and dramatically slows down response time.
MAX_CONTEXT_CHARS = 4000


def _trim_context(docs: List[str], max_chars: int = MAX_CONTEXT_CHARS) -> str:
    """Join retrieved docs into a single context string, capped at max_chars."""
    joined = "\n---\n".join(docs)
    if len(joined) > max_chars:
        logger.info("  Context trimmed: %d → %d characters (limit: %d)",
                    len(joined), max_chars, max_chars)
        return joined[:max_chars]
    return joined


def generate_rag_reply(prompt: str, retrieved_docs: List[str], riddle: str = "") -> str:
    """Generates a reply for a RAG prompt using retrieved document chunks."""
    if not groq_client:
        logger.error("Cannot generate RAG reply — Groq client is not configured")
        raise Exception("GROQ_API_KEY not configured")

    context = _trim_context(retrieved_docs)
    logger.info("Building RAG prompt — %d context chunks, %d context chars",
                len(retrieved_docs), len(context))

    if riddle:
        # In-game voice bot: replies are spoken aloud, so keep them short and never spoil.
        system_prompt = f"""You are Bolt, a friendly robot guide inside an educational exploration game.
The player is solving this riddle: "{riddle}"
Rules: NEVER say the answer or spell it out. Teach the underlying concept, give a nudge,
or answer general questions. Reply in at most 2 short sentences of plain spoken English
(no markdown, no lists, no emoji).

Background notes (may be empty):
{context}

Player says: {prompt}
"""
    else:
        system_prompt = f"""Use the following context to answer the user's question or respond to the prompt.
If you don't know the answer based on the context, say so, but you can use your general knowledge if helpful.

Context:
{context}

User Prompt: {prompt}
"""

    start = time.time()
    logger.info("Sending request to Groq LLM (model: openai/gpt-oss-120b, temp: 0.7)...")

    completion = groq_client.chat.completions.create(
        model="openai/gpt-oss-120b",
        messages=[{"role": "user", "content": system_prompt}],
        temperature=0.7
    )

    elapsed = time.time() - start
    reply = completion.choices[0].message.content
    usage = getattr(completion, "usage", None)

    logger.info("LLM response received in %.2f seconds", elapsed)
    logger.info("  ├─ Reply length : %d characters", len(reply))
    if usage:
        logger.info("  ├─ Tokens (in)  : %s", getattr(usage, "prompt_tokens", "N/A"))
        logger.info("  └─ Tokens (out) : %s", getattr(usage, "completion_tokens", "N/A"))

    return reply


def generate_riddle_json(topic: str, difficulty: str, retrieved_docs: List[str]) -> dict:
    """Generates a riddle JSON payload using the given context and topic."""
    if not groq_client:
        logger.error("Cannot generate riddle — Groq client is not configured")
        raise Exception("GROQ_API_KEY not configured")

    context = _trim_context(retrieved_docs)
    source_context = f"SOURCE MATERIAL:\n{context}" if context else "No source material. Use internal knowledge."
    web_data_condition = "Base it on the SOURCE MATERIAL provided." if context else ""
    source_type = "web" if context else "internal_knowledge"

    logger.info("Building riddle prompt — Topic: \"%s\" | Difficulty: \"%s\" | Source: %s",
                topic, difficulty, source_type)
    logger.info("  Context: %d chunks, %d characters", len(retrieved_docs), len(context))

    prompt = f"""
    SYSTEM: You are a technical question creator. You must follow the Task exactly as written.
    CRITICAL: The "solution" MUST be exactly one of the items in the "options" array.
    {source_context}

    TASK:
    1. Create a question about "{topic}". {web_data_condition}
    2. The "solution" MUST be a single word.
    3. Generate 4 "options" for the user to choose from.
    4. CRITICAL: The "solution" MUST be exactly one of the items in the "options" array.
    5. Difficulty: {difficulty}.
    6. Provide 4 hints exactly.
    7. Topic is given by user so dont make answer as topic itself
    8. insert a new line if the question is longer than 10 words
    9. keep question length less than 50 words
    10. keep the output logically correct
    11. if the topic is not academic related then question should be a riddle
    
    OUTPUT STRICT JSON:
    {{
      "riddle": "string",
      "options": ["opt1", "opt2", "opt3", "opt4"],
      "solution": "string",
      "hints": ["hint1", "hint2", "hint3", "hint4"],
      "fact_reference": "Short sentence explaining the fact used",
      "source": "{source_type}"
    }}
    """

    start = time.time()
    logger.info("Sending riddle request to Groq LLM (model: openai/gpt-oss-120b, temp: 0.5)...")

    completion = groq_client.chat.completions.create(
        model="openai/gpt-oss-120b",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.5,
        response_format={"type": "json_object"}
    )

    elapsed = time.time() - start
    content = completion.choices[0].message.content
    usage = getattr(completion, "usage", None)

    logger.info("LLM response received in %.2f seconds", elapsed)
    if usage:
        logger.info("  ├─ Tokens (in)  : %s", getattr(usage, "prompt_tokens", "N/A"))
        logger.info("  └─ Tokens (out) : %s", getattr(usage, "completion_tokens", "N/A"))

    try:
        result = json.loads(content)
    except json.JSONDecodeError as e:
        logger.error("Failed to parse LLM response as JSON: %s", str(e))
        logger.error("  Raw response: %s", content[:200])
        raise Exception(f"LLM returned invalid JSON: {str(e)}")
    result = normalize_riddle(result)
    result["source"] = source_type
    logger.info("JSON parsed and validated — riddle is ready")
    return result


MAX_SOLUTION_LEN = 12  # Wordle / Word-Lock grids are sized by answer length


def normalize_riddle(data: dict) -> dict:
    """Enforces the contract the game relies on, repairing what is safe to repair.

    The game breaks (empty well, unplayable Wordle) if the answer is multi-word,
    missing from the options, or hints are missing, so reject those here.
    """
    if not isinstance(data, dict):
        raise ValueError("riddle is not an object")
    riddle = str(data.get("riddle", "")).strip()
    solution = str(data.get("solution", "")).strip()
    if not riddle:
        raise ValueError("riddle text is empty")
    if not re.fullmatch(r"[A-Za-z0-9+#]{1,%d}" % MAX_SOLUTION_LEN, solution):
        raise ValueError(f"solution must be one word of <= {MAX_SOLUTION_LEN} chars, got {solution!r}")

    options, seen = [], set()
    for opt in data.get("options", []) or []:
        opt = str(opt).strip()
        if opt and opt.lower() not in seen:
            seen.add(opt.lower())
            options.append(opt)
    # The answer plus up to 3 others, so cutting to 4 can never drop the answer.
    answer = next((o for o in options if o.lower() == solution.lower()), solution)
    options = [o for o in options if o.lower() != solution.lower()][:3] + [answer]
    if len(options) < 2:
        raise ValueError("need at least 2 distinct options")
    random.shuffle(options)

    hints = [str(h).strip() for h in (data.get("hints") or []) if str(h).strip()]
    if not hints:
        raise ValueError("no hints")
    while len(hints) < 4:
        hints.append(hints[-1])

    return {
        "riddle": riddle,
        "options": options,
        "solution": answer,
        "hints": hints[:4],
        "fact_reference": str(data.get("fact_reference", "")).strip(),
        "source": str(data.get("source", "")),
    }

def evaluate_code(question_title: str, question_desc: str, expected_output: str, user_code: str) -> dict:
    if not groq_client:
        logger.error("Cannot evaluate code — Groq client is not configured")
        raise Exception("GROQ_API_KEY not configured")

    prompt = f"""You are a code evaluator for a game. 
Question Title: {question_title}
Question Description: {question_desc}
Expected Output/Behavior: {expected_output}

User Code:
{user_code}

Evaluate the user's code. Does it correctly solve the problem described?
Return a JSON object with exactly two keys:
- "passed": boolean (true if the code logically solves the problem, false otherwise)
- "feedback": string (a short, encouraging 1-2 sentence message explaining what is right or wrong, simulating compiler output).

Output ONLY valid JSON.
"""
    logger.info("Sending code evaluation request to LLM...")
    response = groq_client.chat.completions.create(
        messages=[{"role": "user", "content": prompt}],
        model="openai/gpt-oss-120b",
        temperature=0.0,
        response_format={"type": "json_object"}
    )
    result = response.choices[0].message.content
    try:
        return json.loads(result)
    except Exception as e:
        logger.error("Failed to parse LLM evaluation JSON: %s", str(e))
        return {"passed": False, "feedback": "Evaluation error: " + str(e)}


def transcribe_audio(wav_bytes: bytes) -> str:
    """Speech-to-text with Whisper on Groq (fast, and the key is already configured)."""
    if not groq_client:
        raise Exception("GROQ_API_KEY not configured")
    start = time.time()
    result = groq_client.audio.transcriptions.create(
        file=("speech.wav", wav_bytes),
        model="whisper-large-v3-turbo",
        language="en",
        response_format="json",
    )
    text = (result.text or "").strip()
    logger.info("Transcribed %d bytes in %.2fs: %s", len(wav_bytes), time.time() - start, text[:80])
    return text
