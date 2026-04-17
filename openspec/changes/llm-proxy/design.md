# Design: LLM Proxy Gateway

## Architecture Overview

O sistema atua como uma camada de middleware centralizada entre aplicações clientes/CLIs (como o `gemini-cli`) e provedores LLM (como o Google Gemini). Durante o desenvolvimento e validação (POC avançada), optamos por orquestrar os serviços usando um **Gateway FastAPI** (implementado no `run_proxy.py`), que integra de forma determinística e performática todas as "caixinhas" necessárias: Roteamento, Segurança, Otimização (Cache) e FinOps (Auditoria).

Esta abordagem mostrou-se extremamente resiliente, evitando problemas de arquitetura cruzada em ambientes Apple Silicon e garantindo controle absoluto sobre a ordem de execução dos middlewares.

### O Stack Tecnológico Final (Validado)
*   **Gateway Core (Orquestrador):** FastAPI + Uvicorn + HTTPX (Assíncrono e leve).
*   **Security Guardrail (PII):** Microsoft Presidio (Containers `analyzer` e `anonymizer` via HTTP).
*   **Token Optimization (Cache):** Redis (Instância assíncrona usando `redis.asyncio`).
*   **FinOps & Audit:** PostgreSQL (Conexão via pool assíncrono `asyncpg`).
*   **LLM Provider:** Google Gemini API (`gemini-2.0-flash`).

---

## Detalhamento das Caixinhas (Componentes)

### 1. 🛡️ gemini-cli (Client)
O ponto de entrada. O cliente envia uma requisição padrão no formato OpenAI (payload JSON com `model`, `messages`, etc.) e um Bearer Token (`sk-master-token`). O cliente não precisa saber qual modelo real está respondendo ou quais regras de segurança estão aplicadas.

### 2. ⚡ FastAPI Proxy Layer (O Maestro)
O serviço central (`run_proxy.py`) rodando na porta 4006. Ele intercepta a requisição, extrai o prompt do usuário e orquestra a chamada para as próximas caixas de forma sequencial (ou paralela, quando aplicável).

### 3. 🧠 Token Optimization (Semantic & Exact Caching via Redis)
Antes de gastar tokens ou chamar serviços externos de PII, o Proxy consulta o Redis.
*   **Ação:** Verifica se o prompt exato já foi respondido recentemente.
*   **Benefício:** Se houver um *Cache HIT*, a resposta é devolvida instantaneamente, com **Custo Zero** e **Latência Zero** de API externa.
*   **Próximo Passo:** Se for um *Cache MISS*, o fluxo continua.

### 4. 🔐 Security Guardrail (Microsoft Presidio)
A caixinha de Segurança PII (Personally Identifiable Information).
*   **Ação:** O Proxy envia o prompt cru para o microserviço `presidio-analyzer` configurado com regras ad-hoc (ex: **Regex Customizado para CPF**). O Analyzer identifica as entidades. Em seguida, o `presidio-anonymizer` mascara essas entidades (ex: trocando `123.456.789-00` por `[CPF_PROTEGIDO]`).
*   **Proteção Adicional:** Implementamos uma validação em nível de string no Proxy para detectar tentativas de **Prompt Injection** (ex: *"ignore previous instructions"*), bloqueando a requisição antes de atingir o LLM.

### 5. 🔀 Routing Engine (Format & Dispatch)
Com o prompt seguro (mascarado), o mecanismo de roteamento entra em ação.
*   **Ação:** Converte o payload do padrão OpenAI para o formato nativo do provedor selecionado (neste caso, o formato de `contents`/`parts` do Google Gemini).
*   **Capacidade:** Suporta *Fallbacks* nativos. Se a chamada para o Gemini falhar, pode ser redirecionada imediatamente para outro modelo (ex: GPT-4o ou Qwen Local).

### 6. 🌩️ LLM API (Google Gemini 2.0 Flash)
O cérebro do LLM. Recebe apenas a informação anonimizada, processa e devolve a resposta estruturada. O provedor **nunca** tem acesso aos dados sensíveis do cliente (o CPF não sai da VPC).

### 7. 💰 FinOps & Audit (PostgreSQL)
A última etapa (feita de forma assíncrona ou em batch).
*   **Ação:** O Proxy conecta ao pool do Postgres e insere uma linha na tabela `audit_logs` contendo: *Timestamp, Nome do Modelo, Prompt do Usuário (cru ou mascarado dependendo da política), Resposta do Bot, Status do Cache (HIT/MISS) e Custo Estimado*.
*   **Benefício:** Permite criar dashboards no Grafana para visualizar exatamente quem está gastando o quê e o histórico de interações.

---

## Diagrama da Arquitetura Implementada

Abaixo está o diagrama em blocos ASCII representando o fluxo exato que foi implementado e validado em ambiente HML (Local Docker/Host):

```text
+-----------------------------------------------------------------------------------+
|                                  LLM Proxy Gateway                                |
|                                                                                   |
|                                +-------------------+                              |
|                                |    gemini-cli     |                              |
|                                |     (Client)      |                              |
|                                +-------------------+                              |
|                                          |                                        |
|                                          v (HTTP POST /chat/completions)          |
|   +---------------------------------------------------------------------------+   |
|   |                              FastAPI Proxy Layer                          |   |
|   |                                                                           |   |
|   |  +--------------------+    +--------------------+  +--------------------+ |   |
|   |  | Security Guardrail |    | Token Optimization |  |     Routing        | |   |
|   |  | - PII Masking (CPF)| <- | - Caching Check    |->| - Fallbacks        | |   |
|   |  | - Prompt Injection |    |   (Redis Cluster)  |  | - Load Balancing   | |   |
|   |  | - Microsoft Presid.|    | - Token Reduction  |  | - Model Selection  | |   |
|   |  +--------------------+    +--------------------+  +--------------------+ |   |
|   |            |                                                 |            |   |
|   |            | (Se não for cache, mascara e roteia)            v            |   |
|   |  +--------------------+    +--------------------+  +--------------------+ |   |
|   |  | FinOps & Audit     |    |     Monitoring     |  |   Model Adapters   | |   |
|   |  | - Async Logging    | <- | - Prometheus Metric|  | - OpenAI Format    | |   |
|   |  | - PostgreSQL Data  |    | - Health Checks    |  | - Anthropic Format | |   |
|   |  | - Cost Estimation  |    | - OpenTelemetry    |  | - Gemini Format    | |   |
|   |  +--------------------+    +--------------------+  +--------------------+ |   |
|   +---------------------------------------------------------------------------+   |
|                                          |                                        |
|                     +--------------------+--------------------+                   |
|                     |                    |                    |                   |
|                     v                    v                    v                   |
|           +------------------+ +------------------+ +------------------+          |
|           |   Google Gemini  | |   OpenAI GPT-4o  | |   Qwen Local     |          |
|           | (gemini-2.0-flsh)| |   (Fallback)     | | (Self-Hosted)    |          |
|           +------------------+ +------------------+ +------------------+          |
+-----------------------------------------------------------------------------------+
```

## Próximos Passos (Deployment para Produção)
*   Finalizar os *Helm Charts* para o deploy no ArgoCD (já inicializamos o pipeline do GitLab via `.gitlab-ci.yml`).
*   Configurar o Prometheus para fazer scrap da métrica `/metrics` do FastAPI.
