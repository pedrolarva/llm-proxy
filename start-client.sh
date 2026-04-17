#!/bin/bash

# ==============================================================================
# Script de Inicialização: Gemini CLI via LiteLLM Oficial
# ==============================================================================

PROXY_URL="http://127.0.0.1:4000"

# O token master do seu Gateway
MASTER_API_KEY="${LITELLM_MASTER_KEY:-sk-master-token}"

echo "🚀 Conectando gemini-cli ao LiteLLM Proxy em $PROXY_URL..."

export NODE_TLS_REJECT_UNAUTHORIZED=0
export GOOGLE_GEMINI_BASE_URL="$PROXY_URL"
export GEMINI_API_KEY="$MASTER_API_KEY"
export GOOGLE_API_KEY="$MASTER_API_KEY"

GEMINI_BIN="$(which gemini 2>/dev/null || echo 'gemini')"

# Executa o CLI pedindo explicitamente o modelo que o proxy entende
"$GEMINI_BIN" --model "gemini-3.1-flash" "$@"
