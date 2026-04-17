#!/bin/bash
set -e

echo "⏳ Waiting for LiteLLM to be ready..."
# Aumentando o timeout para dar tempo do Postgres e Redis subirem
for i in {1..45}; do
  if curl -s http://localhost:4000/health/readiness | grep -q "\"status\": \"connected\""; then
    echo "✅ LiteLLM is UP!"
    break
  fi
  if [ $i -eq 45 ]; then
    echo "❌ Timeout waiting for LiteLLM"
    exit 1
  fi
  echo "...waiting ($i)"
  sleep 2
done

echo "🔍 Checking Prometheus Metrics..."
if curl -s http://localhost:4000/metrics | grep -q "litellm_"; then
  echo "✅ Metrics endpoint is active."
else
  echo "❌ Metrics endpoint failed or empty."
  exit 1
fi

echo "🔑 Testing Virtual Key Generation..."
# Usando o master key configurado no docker-compose / .env do CI
RESPONSE=$(curl -s -X POST 'http://localhost:4000/key/generate' \
  -H 'Authorization: Bearer sk-master-token' \
  -H 'Content-Type: application/json' \
  -d '{
    "models": ["gemini-enterprise"],
    "metadata": {"squad": "ci-test"},
    "max_budget": 10.0
  }')

if echo "$RESPONSE" | grep -q "key"; then
  echo "✅ Virtual Key generated successfully."
else
  echo "❌ Virtual Key generation failed: $RESPONSE"
  exit 1
fi

echo "🚀 All functional tests passed!"
