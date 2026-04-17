# Tasks: LLM Proxy Gateway

## Setup and Scaffolding
- [x] Initialize Python/FastAPI environment with dependency management (e.g., `venv`).
- [x] Configure Dockerfile and docker-compose to run the proxy service locally alongside required dependencies (e.g., Redis).
- [x] Integrate LiteLLM as the core routing layer (or build initial HTTP routes).

## Security and PII Guardrails
- [x] Implement Microsoft Presidio (via sidecar) for intercepting requests and scanning for sensitive data (CPF, credit cards).
- [x] Add basic prompt injection detection.
- [x] Decide on a configuration format (YAML or JSON) to quickly toggle these security policies per application.

## FinOps and Audit Logging
- [x] Set up PostgreSQL for async storing of audit logs.
- [x] Connect Redis array to track total tokens/cost per Virtual API key limit.
- [x] Provide simple reporting endpoints or Grafana dashboard config for FinOps visibility.

## Token Optimization (Caching)
- [x] Implement LiteLLM Semantic Caching via Redis + text-embedding-3 to intercept identical/similar developer queries instantly without incurring LLM charges.
- [x] Configure Proxy passthrough endpoints (`/v1/messages` for Anthropic, `/v1/generateContent` for Gemini) and enable `forward_client_headers_to_llm_api` to ensure developers can actively use native Context Caching for large files/codebases.

## Routing and Model Choice
- [x] Configure `gemini-cli` to point to the proxy's endpoint using a mock API Key.
- [x] Create routing logic: intercept requests to the default model, select a specific underlying model (e.g., `gemini-3.1-flash` or `qwen-local`) based on preset rules or headers.
- [x] Handle error scenarios, load balancing, and fallbacks.

## Deployment to Staging (HML)
- [x] Define initial GitLab CI/CD pipeline configuration (`.gitlab-ci.yml`).
- [ ] Write Helm charts or Kubernetes manifests for ArgoCD deployment.
- [ ] Deploy to Staging (HML) for initial tests.

## Monitoring
- [x] Expose `/metrics` endpoint (Prometheus format) for system health, latency, error rate, and model usage metrics.
- [ ] Integrate OpenTelemetry (optional, for deeper tracing of multi-model LLM calls).
