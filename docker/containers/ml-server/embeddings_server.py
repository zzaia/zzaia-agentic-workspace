#!/usr/bin/env python3
"""
Embeddings server for ml-server — exposes local sentence-transformers model via OpenAI-compatible API.
Loads nomic-ai/nomic-embed-text-v1.5 and serves on port 8788.
Requires: sentence-transformers, fastapi, uvicorn (GPU mode only).
"""

import os
import sys
from typing import Union, List
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import logging

try:
    from sentence_transformers import SentenceTransformer
except ImportError:
    print("Error: sentence-transformers not installed. GPU mode enabled?", file=sys.stderr)
    sys.exit(1)

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO, format="[embeddings-server] %(message)s")
logger = logging.getLogger(__name__)

# ── Configuration ─────────────────────────────────────────────────────────────
MODEL_NAME = "nomic-ai/nomic-embed-text-v1.5"
MODEL_OUTPUT_DIMS = 768
CACHE_DIR = os.getenv("HF_HOME", "/opt/ml-tools/.cache/huggingface")

# Set environment variables for model caching
os.environ.setdefault("HF_HOME", CACHE_DIR)
os.environ.setdefault("TRANSFORMERS_CACHE", os.path.join(CACHE_DIR, "hub"))
os.environ.setdefault("SENTENCE_TRANSFORMERS_HOME", os.path.join(CACHE_DIR, "sentence-transformers"))

# ── Request/Response Models (OpenAI-compatible) ─────────────────────────────
class EmbeddingRequest(BaseModel):
    input: Union[str, List[str]]
    model: str = MODEL_NAME


class EmbeddingData(BaseModel):
    object: str = "embedding"
    embedding: List[float]
    index: int


class EmbeddingResponse(BaseModel):
    object: str = "list"
    data: List[EmbeddingData]
    model: str


# ── Initialize FastAPI app ─────────────────────────────────────────────────
app = FastAPI(title="ml-server-embeddings", version="1.0.0")
model = None


# ── Model initialization ───────────────────────────────────────────────────
def load_model():
    global model
    if model is not None:
        return
    logger.info(f"Loading model {MODEL_NAME} (cache: {CACHE_DIR})...")
    try:
        model = SentenceTransformer(
            MODEL_NAME,
            cache_folder=CACHE_DIR,
            trust_remote_code=True,
            device="cuda" if has_cuda() else "cpu"
        )
        logger.info(f"Model loaded successfully (dims: {MODEL_OUTPUT_DIMS})")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise


def has_cuda():
    try:
        import torch
        return torch.cuda.is_available()
    except ImportError:
        return False


# ── Routes ──────────────────────────────────────────────────────────────────
@app.get("/health", status_code=200)
async def health():
    """Health check — indicates readiness once model is loaded."""
    if model is None:
        return {"status": "loading"}
    return {"status": "ok", "model": MODEL_NAME, "dimensions": MODEL_OUTPUT_DIMS}


@app.post("/v1/embeddings", response_model=EmbeddingResponse)
async def embeddings(req: EmbeddingRequest):
    """Generate embeddings for input text(s) — OpenAI-compatible endpoint."""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not ready")

    # Normalize input to list
    texts = req.input if isinstance(req.input, list) else [req.input]

    try:
        # Generate embeddings
        embeddings = model.encode(texts, convert_to_numpy=True)

        # Build response
        data = []
        for i, emb in enumerate(embeddings):
            data.append(
                EmbeddingData(
                    object="embedding",
                    embedding=emb.tolist(),
                    index=i
                )
            )

        return EmbeddingResponse(
            object="list",
            data=data,
            model=MODEL_NAME
        )
    except Exception as e:
        logger.error(f"Embedding error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.on_event("startup")
async def startup():
    """Load model on startup."""
    load_model()


if __name__ == "__main__":
    import uvicorn
    load_model()
    uvicorn.run(app, host="0.0.0.0", port=8788, log_level="info")
