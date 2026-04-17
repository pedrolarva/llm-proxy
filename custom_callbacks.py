import litellm
import aiohttp
import os

async def presidio_handler(data, fallback_model_group, cache_hit):
    if cache_hit:
        return data

    messages = data.get("messages", [])
    if not messages:
        return data

    # Using internal Docker network URLs
    analyzer_url = os.getenv("PRESIDIO_URL", "http://presidio-analyzer:3000/analyze")
    anonymizer_url = os.getenv("PRESIDIO_ANONYMIZER_URL", "http://presidio-anonymizer:3000/anonymize")

    async with aiohttp.ClientSession() as session:
        for message in messages:
            content = message.get("content", "")
            
            if isinstance(content, str):
                if "ignore previous instructions" in content.lower():
                    raise Exception("Prompt Injection Detected - Request Blocked")

                analyze_payload = {
                    "text": content,
                    "language": "en", 
                    "entities": ["PHONE_NUMBER", "CREDIT_CARD", "EMAIL_ADDRESS", "LOCATION", "PERSON"],
                    "ad_hoc_recognizers": [{
                        "name": "CPF_RECOGNIZER",
                        "supported_entity": "CPF",
                        "patterns": [{"name": "cpf_pattern", "score": 0.8, "regex": "\\d{3}\\.\\d{3}\\.\\d{3}-\\d{2}|\\d{11}"}],
                        "supported_language": "en"
                    }]
                }
                analyze_payload["entities"].append("CPF")

                try:
                    async with session.post(analyzer_url, json=analyze_payload) as resp:
                        if resp.status == 200:
                            analysis_results = await resp.json()
                            if analysis_results:
                                anonymize_payload = {
                                    "text": content,
                                    "analyzer_results": analysis_results
                                }
                                async with session.post(anonymizer_url, json=anonymize_payload) as anon_resp:
                                    if anon_resp.status == 200:
                                        anonymized_data = await anon_resp.json()
                                        message["content"] = anonymized_data.get("text", content)
                                        print("🛡️ PII Mascarado via Presidio Sidecar!")
                except Exception as e:
                    print(f"WARN - Presidio Error: {e}")

    return data

# Registra o hook de pré-processamento (PII Masking)
litellm.input_callbacks = [presidio_handler]
