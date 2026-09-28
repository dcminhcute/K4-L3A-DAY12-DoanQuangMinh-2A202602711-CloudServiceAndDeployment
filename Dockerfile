# ═══════════════════════════════════════════════════════════════════
# CP2 — Production Dockerfile (multi-stage, non-root, healthcheck)
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder — được phép nặng, sẽ bị vứt đi ────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# Compiler chỉ tồn tại ở stage này (cần nếu có thư viện phải biên dịch)
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

# requirements.txt copy + pip install TRƯỚC source code để tận dụng cache layer
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: runtime — image cuối cùng ─────────────────────────────
FROM python:3.11-slim AS runtime

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000

WORKDIR /app

# Chỉ mang KẾT QUẢ cài đặt sang, không mang compiler
COPY --from=builder /install /usr/local

# User thường, không phải root
RUN useradd --create-home --uid 10001 appuser

# Code copy SAU cùng: sửa code không làm mất cache của pip install
COPY --chown=appuser:appuser app ./app
COPY --chown=appuser:appuser utils ./utils

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/health' % os.environ.get('PORT', '8000'), timeout=3).read()"]

# 0.0.0.0 để gọi được từ ngoài container; cổng lấy từ $PORT do cloud gán
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]