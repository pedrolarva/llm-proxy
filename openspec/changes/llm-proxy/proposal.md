# Proposal: LLM Proxy Gateway

## What
Create an LLM proxy gateway capable of intercepting requests from clients (such as `gemini-cli`), applying a series of verifications and validations, and routing them to multiple LLM providers (Gemini, Qwen, Minimax, etc.).

## Why
As the usage of LLMs scales, there is a critical need to centralize governance, cost tracking, security, and observability instead of having scattered direct integrations. This proxy will ensure:
- **Auditoria (Audit):** A complete trail of all incoming prompts and outgoing responses.
- **FinOps:** Accurate tracking of token usage, latency, and cost per application/user.
- **Segurança (Security):** Guardrails to avoid data exfiltration, PII leakage, or malicious prompt injection before it reaches the models.
- **Escolha do Modelo (Model Routing):** Dynamic or configuration-driven routing of requests to the most appropriate or cost-effective model without needing code changes at the client side.
- **Monitoria (Monitoring):** Centralized logs, metrics, and error rates to guarantee SLIs/SLOs.
- **Otimização de Tokens (Token Optimization):** Implementation of **Semantic Caching** to bypass LLM calls for repeated/similar queries (cutting latency/cost to zero for hits), and pass-through support for **Context Caching** (Anthropic/Gemini) to save up to 90% on long static prompts.

## Context

Clients will point their base URLs to this proxy rather than directly to the provider endpoints. The proxy will emulate standard LLM APIs (like the OpenAI or Gemini API formats) to act as a seamless drop-in replacement.

### Market Context & Solution Validation
Based on current open-source alternatives like **Nvidia NeMo Guardrails**, **Portkey**, **Bifrost**, and **Helicone**, the proposed architecture is aligned with industry best practices:
- **Routing & FinOps:** **LiteLLM** is the most widely adopted open-source proxy for multi-model routing (100+ models) and FinOps (via virtual keys and budgets). In contrast, tools like Helicone focus purely on observability, and OneAPI on simple quotas.
- **Security & PII Guardrails:** While **Nvidia NeMo Guardrails** provides deep, programmable application-level security (Colang logic), it is complex and coupled tightly to the application code. By placing the security layer at the Gateway (similar to what LiteLLM can do with Microsoft Presidio or what Portkey offers natively), we achieve centralized security for all connected clients (like `gemini-cli`) without needing code changes in the clients themselves.
- **Conclusion:** We are on the right path. Using a centralized proxy (LiteLLM at the core) wrapped with custom middleware for PII/Audit provides the perfect balance of flexibility, model choices, and centralized governance required by the current diagram.
