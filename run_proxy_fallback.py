import asyncio
import httpx
import os
import uvicorn
import json
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse

app = FastAPI()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "SUA_CHAVE_AQUI")
GOOGLE_STREAM_URL = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:streamGenerateContent?alt=sse&key={GEMINI_API_KEY}"

@app.api_route("/{path:path}", methods=["GET", "POST"])
async def proxy_handler(request: Request, path: str):
    if request.method == "GET": return {"status": "healthy"}

    body = await request.body()
    try: data = json.loads(body)
    except: data = {}

    user_prompt = "Oi"
    if 'messages' in data: user_prompt = data['messages'][0]['content']
    elif 'contents' in data: user_prompt = data['contents'][0]['parts'][0]['text']
    
    safe_prompt = user_prompt.replace("123.456.789-00", "[CPF_MASCARADO]")
    google_payload = {"contents": [{"parts": [{"text": safe_prompt}]}]}

    async def stream_generator():
        client = httpx.AsyncClient()
        async with client.stream("POST", GOOGLE_STREAM_URL, json=google_payload, timeout=60.0) as resp:
            async for line in resp.aiter_lines():
                if line:
                    # O Google manda 'data: {json}'. O aiter_lines tira o prefixo as vezes se for SSE nativo.
                    # Mas o httpx aiter_lines nos da a linha crua.
                    # Vamos garantir que cada linha tenha o formato que o CLI espera.
                    yield f"{line}\n"
        await client.aclose()

    # O media_type deve ser exatamente o que o Google manda: text/event-stream
    return StreamingResponse(stream_generator(), media_type="text/event-stream")

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=4000)
