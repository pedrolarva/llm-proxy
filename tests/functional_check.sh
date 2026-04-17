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

echo "🔑 Testing Virtual Key Generation (Generating Activity)..."
RESPONSE=$(curl -s -X POST 'http://localhost:4000/key/generate' \
  -H 'Authorization: Bearer sk-master-token' \
  -H 'Content-Type: application/json' \
  -d '{
    "models": ["gemini-enterprise"],
    "metadata": {"squad": "ci-test"},
    "max_budget": 10.0
  }')

echo "Key Response: $RESPONSE"
if echo "$RESPONSE" | grep -q "key"; then
  echo "✅ Virtual Key generated successfully."
else
  echo "❌ Virtual Key generation failed."
  exit 1
fi

echo "🔍 Checking Prometheus Metrics..."
# Dando um pequeno tempo para o callback processar
sleep 5
METRICS=$(curl -s http://localhost:4000/metrics || echo "")
if echo "$METRICS" | grep -q "litellm_"; then
  echo "✅ Metrics endpoint is active."
  echo "--- Metrics Sample ---"
  echo "$METRICS" | grep "litellm_" | head -n 5
else
  echo "❌ Metrics endpoint failed or empty."
  echo "Full Metrics Output: '$METRICS'"
  exit 1
fi

echo "🚀 All functional tests passed!"
