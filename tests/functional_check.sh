#!/bin/bash
set -e

echo "⏳ Waiting for LiteLLM to be ready..."
for i in {1..60}; do
  STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4000/health/readiness || echo "000")
  if [ "$STATUS_CODE" == "200" ]; then
    RESPONSE=$(curl -s http://localhost:4000/health/readiness)
    echo "Response: $RESPONSE"
    if echo "$RESPONSE" | grep -q "\"status\": \"connected\""; then
      echo "✅ LiteLLM is UP and Connected to DB/Redis!"
      break
    fi
  fi
  if [ $i -eq 60 ]; then
    echo "❌ Timeout waiting for LiteLLM. Last status: $STATUS_CODE"
    echo "--- LITELLM LOGS ---"
    docker compose logs litellm
    exit 1
  fi
  echo "...waiting ($i) - Status: $STATUS_CODE"
  sleep 2
done

echo "🔍 Checking Prometheus Metrics..."
METRICS=$(curl -s http://localhost:4000/metrics || echo "")
if echo "$METRICS" | grep -q "litellm_"; then
  echo "✅ Metrics endpoint is active."
else
  echo "❌ Metrics endpoint failed or empty."
  echo "Metrics output: $METRICS"
  exit 1
fi

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
if echo "$RESPONSE" | grep -q "key"; then
  echo "✅ Virtual Key generated successfully."
else
  echo "❌ Virtual Key generation failed."
  exit 1
fi

echo "🚀 All functional tests passed!"
