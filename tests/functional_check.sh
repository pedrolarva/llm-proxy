#!/bin/bash
set -e

echo "⏳ Waiting for LiteLLM to be fully ready (Health + DB)..."
for i in {1..120}; do
  STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4000/health/readiness || echo "000")
  if [ "$STATUS_CODE" == "200" ]; then
    RESPONSE=$(curl -s http://localhost:4000/health/readiness)
    echo "Response: $RESPONSE"
    if echo "$RESPONSE" | grep -q "\"status\":\"healthy\"" && echo "$RESPONSE" | grep -q "\"db\":\"connected\""; then
      echo "✅ LiteLLM is UP and Connected!"
      break
    fi
  fi
  if [ $i -eq 120 ]; then
    echo "❌ Timeout waiting for LiteLLM."
    docker compose logs litellm
    exit 1
  fi
  echo "...waiting ($i) - Status: $STATUS_CODE"
  sleep 5
done

echo "🔑 Testing Virtual Key Generation..."
RESPONSE=$(curl -s -X POST 'http://localhost:4000/key/generate' \
  -H 'Authorization: Bearer sk-master-token' \
  -H 'Content-Type: application/json' \
  -d '{
    "models": ["gemini-enterprise"],
    "metadata": {"squad": "ci-test"},
    "max_budget": 10.0
  }')

echo "Key Response: $RESPONSE"
VIRTUAL_KEY=$(echo "$RESPONSE" | grep -oP '"key":\s*"\K[^"]+')

if [ -z "$VIRTUAL_KEY" ]; then
  echo "❌ Virtual Key generation failed."
  exit 1
fi
echo "✅ Virtual Key: $VIRTUAL_KEY"

echo "💬 Making a dummy chat request to trigger metrics..."
# Esta chamada vai falhar no backend (mock key), mas deve registrar a tentativa nas métricas
curl -s -X POST 'http://localhost:4000/chat/completions' \
  -H "Authorization: Bearer $VIRTUAL_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gemini-enterprise",
    "messages": [{"role": "user", "content": "hi"}]
  }' || echo "Expected failure on backend call"

echo "🔍 Checking Prometheus Metrics..."
sleep 5
METRICS=$(curl -s http://localhost:4000/metrics || echo "")
if echo "$METRICS" | grep -q "litellm_"; then
  echo "✅ Metrics endpoint is active."
  echo "--- Metrics Sample ---"
  echo "$METRICS" | grep "litellm_" | head -n 10
else
  echo "⚠️ Metrics endpoint returned nothing. Retrying in 10s..."
  sleep 10
  METRICS=$(curl -s http://localhost:4000/metrics || echo "")
  if echo "$METRICS" | grep -q "litellm_"; then
     echo "✅ Metrics endpoint is active after retry."
  else
     echo "❌ Metrics endpoint still failed."
     echo "Full Metrics Output: '$METRICS'"
     exit 1
  fi
fi

echo "🚀 All functional tests passed!"
