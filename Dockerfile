# ---------- Étape 1 : construction des dépendances (jetable, non livrée) ----------
FROM python:3.12.8-slim-bookworm AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /build

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Les dépendances d'abord : cette couche change rarement, le cache est réutilisé
COPY requirements.txt .
RUN pip install -r requirements.txt

# ---------- Étape 2 : image finale, minimale ----------
FROM python:3.12.8-slim-bookworm AS runtime

# Valeurs injectées UNE SEULE FOIS, à la construction par la CI (l'image n'est jamais reconstruite)
ARG VERSION=dev
ARG REVISION=unknown
ARG SOURCE=https://github.com/OWNER/pretlab

LABEL org.opencontainers.image.title="pretlab" \
      org.opencontainers.image.description="API de prêt de matériel de laboratoire" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.source="${SOURCE}"

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    APP_VERSION=${VERSION} \
    APP_REVISION=${REVISION}

# Utilisateur système sans privilèges, sans shell de connexion
RUN groupadd --system app && useradd --system --gid app --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY --chown=app:app src/pretlab ./pretlab

USER app
EXPOSE 8080

# Vivacité interne : 127.0.0.1 est correct ICI (le test s'exécute dans le conteneur)
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=2)"

# 0.0.0.0 : indispensable pour être joignable depuis l'extérieur du conteneur
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--access-logfile", "-", "pretlab.main:create_app()"]
