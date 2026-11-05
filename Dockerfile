# Images Docker Hardened Images (DHI) : pull authentifie avec un compte Docker Hub
# (docker login dhi.io).

# --- Stage de build : variante -dev (shell, apt) pour installer les dependances ---
FROM dhi.io/python:3.14-debian13-dev AS build

# Binaire uv officiel (image distroless dediee), pas d'installation via pip necessaire.
COPY --from=ghcr.io/astral-sh/uv:0.12.13 /uv /usr/local/bin/

# UV_PYTHON_DOWNLOADS=never : le venv doit utiliser le Python de l'image (meme chemin
# dans le stage runtime), jamais un Python telecharge par uv.
ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON_DOWNLOADS=never \
    UV_PROJECT_ENVIRONMENT=/app/.venv

WORKDIR /app

# Couche dependances seule, pour beneficier du cache Docker tant que pyproject/uv.lock ne changent pas.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

# --- Stage runtime : image minimale, sans shell ni gestionnaire de paquets ---
# Certificats CA inclus, utilisateur non-root (nonroot, uid 65532) par defaut.
FROM dhi.io/python:3.14-debian13 AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Verification TLS des appels HTTP vers Keycloak, figee au build de l'image (et non au
# deploiement) : passer a "false" ici uniquement pour une image de dev face a un
# certificat auto-signe, jamais en dehors de ce cas. Non surchargeable via .env/ConfigMap.
ENV HTTP_VERIFY_TLS=true

WORKDIR /app

# Fichiers en lecture seule pour l'utilisateur d'execution (proprietaire root).
COPY --from=build /app/.venv /app/.venv
COPY app ./app

EXPOSE 8080

CMD ["/app/.venv/bin/uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
