# Endless Worlds — System Architecture

> How the game generates questions from the web in real-time.

## Overall Flow

```mermaid
flowchart TD
    subgraph GODOT["🎮 Godot Game"]
        A["Player hits a riddle trigger"] --> B["GeminiRiddle.gd calls /api/scrape"]
        B --> C["Waits... loading bar crawls 0→50%"]
        C --> D["Scrape done → calls /api/generate_riddle"]
        D --> E["Waits... loading bar crawls 50→90%"]
        E --> F["Riddle received → shows question popup"]
        F --> G["Loading bar hits 100% ✔"]
    end

    subgraph PYTHON["🐍 Python Server (FastAPI — port 8000)"]
        direction TB
        S1["/api/scrape"] --> S2["/api/generate_riddle"]
    end

    B -- "POST topic" --> S1
    D -- "POST topic + difficulty" --> S2
    S2 -- "JSON riddle" --> F
```

## Scrape Pipeline — `/api/scrape`

```mermaid
flowchart LR
    A["Receive topic"] --> B{"Topic already\nindexed?"}
    B -- yes --> I
    B -- no --> C["Search DuckDuckGo\n(fallback: Bing, Brave)"]
    C --> D["Scrape top URLs\n(5 at once, concurrent)"]
    D --> E["Clean HTML\nremove scripts, nav, etc."]
    E --> F["Split text into\n500-char chunks"]
    F --> G["Embed chunks\n(MiniLM model)"]
    G --> H["Store in this topic's own\nFAISS index (LRU of 64)"]
    H --> I["Return URL +\nchunk count"]
```

## Riddle Generation — `/api/generate_riddle`

```mermaid
flowchart LR
    A["Receive topic\n+ difficulty"] --> B["Search FAISS\nfor relevant chunks"]
    B --> C["Build prompt with\ncontext (max 4000 chars)"]
    C --> D["Send to Groq LLM\n(GPT-oss-120B)"]
    D --> E["Parse + validate JSON\n(1-word answer in options,\n4 hints; 1 retry)"]
    E --> F["Return riddle:\nquestion, options,\nanswer, hints"]
```

## Component Map

```mermaid
graph TB
    subgraph GAME["🎮 Godot (GDScript)"]
        GR["gemini_riddle.gd\n— Orchestrates flow"]
        AP["answer_popup.gd\n— Shows question UI"]
        GR --> AP
    end

    subgraph SERVER["🐍 Python Server"]
        MAIN["main.py\n— FastAPI routes"]
        SCRAPER["scraper.py\n— DuckDuckGo + web fetch"]
        VDB["vectordb.py\n— FAISS + embeddings"]
        LLM["llm.py\n— Groq API calls"]

        MAIN --> SCRAPER
        MAIN --> VDB
        MAIN --> LLM
    end

    subgraph EXTERNAL["☁️ External Services"]
        DDG["DuckDuckGo\n— Web search"]
        WEB["Websites\n— Scraped content"]
        GROQ["Groq Cloud\n— LLM inference"]
    end

    GR -- "HTTP" --> MAIN
    SCRAPER --> DDG
    SCRAPER --> WEB
    LLM --> GROQ
```

## File Structure

```
python_server/
├── main.py              ← API routes: /api/scrape, /api/rag, /api/generate_riddle
├── requirements.txt     ← Python dependencies
├── start_server.bat     ← Quick-start script
├── models/
│   └── schemas.py       ← Request/response models
└── services/
    ├── scraper.py       ← DuckDuckGo search + concurrent web scraping
    ├── vectordb.py      ← FAISS vector store + MiniLM embeddings
    └── llm.py           ← Groq LLM calls + context trimming
```

## How It All Connects (Simple Version)

```
Player walks into trigger
        ↓
  "What topic?" → "origami"
        ↓
  Search the web for "origami"
        ↓
  Scrape a webpage about origami
        ↓
  Chop the text into small pieces
        ↓
  Store pieces as vectors (numbers)
        ↓
  Find the most relevant pieces
        ↓
  Ask the AI to write a question
        ↓
  Show the question to the player
        ↓
  Player answers → score updates 🎉
```

## Voice endpoints

- `POST /api/transcribe`: raw 16-bit PCM WAV body (max 4 MB), returns `{"text": ...}` via Groq Whisper (`whisper-large-v3-turbo`).
- `POST /api/rag` with a `riddle` field: Bolt's spoiler-free guide persona (≤ 2 spoken sentences, never states the answer).
- `GET /health`: `{"status": "ok", "llm": true|false}`; the home screen uses it for the online/offline badge.

Endpoints are plain `def`, so FastAPI runs them in its thread pool and one slow scrape can't block other players.
Set `DISABLE_SSL_VERIFY=1` only on machines whose antivirus/proxy intercepts HTTPS (`start_server.bat` does this).
