# LLM Proxy Gateway

Um gateway centralizado baseado no **LiteLLM** projetado para interceptar, auditar e proteger chamadas para APIs de Inteligência Artificial Generativa, como o Google Gemini, OpenAI, entre outros.

## 🌟 Funcionalidades
*   **Token Optimization (Caching):** Utiliza o Redis para cache semântico de requisições, devolvendo a resposta localmente caso seja identificada uma pergunta idêntica prévia.
*   **Security Guardrail (PII Masking):** Integra-se de forma transparente via Sidecar com o microserviço do **Microsoft Presidio** para identificar e mascarar PIIs (ex. CPF) antes que o prompt atinja a nuvem do provedor.
*   **FinOps & Auditoria:** Grava e centraliza métricas de token (cost estimation) em um cluster **PostgreSQL**, com a possibilidade de dashboardização via Grafana.
*   **Roteamento Padrão de Mercado:** Fallbacks e conversão de payloads nativamente em um formato Universal, mantendo compatibilidade direta com `gemini-cli`, LangChain ou LlamaIndex.

## 🚀 Como fazer o Deploy (Ambiente x86 Produção/HML)

Este repositório está otimizado para servidores Linux x86/amd64 usando o orquestrador Docker.

### 1. Configure as Variáveis de Ambiente
Crie um arquivo `.env` na raiz do projeto com as suas credenciais:
```env
GEMINI_API_KEY=sua-chave-api-google-aqui
LITELLM_MASTER_KEY=sk-master-token
```

### 2. Suba a Infraestrutura via Docker
Execute o `docker-compose` para orquestrar todos os containers (LiteLLM, Postgres, Redis, Presidio Analyzer e Anonymizer).

```bash
docker-compose up -d
```

### 3. Valide o Serviço
O proxy subirá por padrão na porta `4000`. Teste o health check e o endpoint principal:
```bash
curl http://localhost:4000/health/readiness
```

## 🛠️ Gerenciamento Corporativo (Management APIs)

Agora o gateway suporta chaves virtuais e orçamentos por Squad.

### 1. Gerar uma Chave para uma Squad
```bash
curl -X POST 'http://localhost:4000/key/generate' \
-H 'Authorization: Bearer sk-master-token' \
-H 'Content-Type: application/json' \
-D '{
  "models": ["gemini-enterprise"],
  "metadata": {"squad": "data-science"},
  "max_budget": 50.0,
  "budget_duration": "30d"
}'
```

### 2. Monitoramento (Prometheus)
As métricas estão disponíveis nativamente no endpoint:
`http://localhost:4000/metrics`

---

## 🛠️ Como usar com o `gemini-cli`
Para os desenvolvedores locais, basta rodar o script `start-client.sh` no repositório. Ele abstrai o redirecionamento TLS/SSL e aponta o tráfego do Node.js/Google SDK para o Proxy local:
```bash
./start-client.sh chat
```

## 🗂️ Estrutura do Projeto
- `docker-compose.yml`: A orquestração das caixinhas, incluindo o LiteLLM.
- `litellm-config.yaml`: Mapeamentos de Modelos e Políticas do Gateway.
- `custom_callbacks.py`: Lógica pura em Python que intercepta as chamadas e faz o offload de proteção PII para o Presidio (Sidecar).
- `run_proxy_fallback.py`: Script FastAPI standalone caso necessite de proxy alternativo (debug).
- `start-client.sh`: Entrypoint wrapper para desenvolvedores locais consumirem a API.
