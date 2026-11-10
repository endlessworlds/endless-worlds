# Backend image for Hugging Face Spaces (Docker SDK), Render, Railway or Fly.io.
# Needs ~1.5 GB RAM because of the sentence-transformers embedding model.
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
# CPU-only torch keeps the image ~1 GB instead of ~5 GB with CUDA.
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu \
 && pip install --no-cache-dir -r requirements.txt

# Bake the embedding model into the image so cold starts don't download it.
RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"

COPY . .
RUN useradd -m app && chown -R app /app
USER app

# Hugging Face Spaces expects 7860; Render/Railway inject $PORT.
ENV PORT=7860
EXPOSE 7860
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT}"]
