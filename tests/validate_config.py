import yaml
import os
import sys

# Simulação básica de validação caso litellm não esteja instalado no ambiente de execução do terminal
# Mas tentaremos importar se possível.
try:
    from litellm import Router
    LITELLM_AVAILABLE = True
except ImportError:
    LITELLM_AVAILABLE = False

def test_config_initialization():
    config_path = "litellm-config.yaml"
    if not os.path.exists(config_path):
        print(f"❌ Config file not found at {config_path}")
        sys.exit(1)
        
    with open(config_path, "r") as f:
        try:
            config = yaml.safe_load(f)
            print("✅ YAML parsed successfully.")
        except Exception as e:
            print(f"❌ YAML parse failed: {e}")
            sys.exit(1)
    
    # Mock environment variables
    os.environ["GEMINI_API_KEY"] = "sk-mock-key"
    os.environ["LITELLM_MASTER_KEY"] = "sk-master-key"
    os.environ["DATABASE_URL"] = "postgresql://user:pass@localhost:5432/db"
    
    if LITELLM_AVAILABLE:
        try:
            # Test Router initialization
            router = Router(model_list=config.get("model_list", []), 
                            redis_host="localhost", 
                            redis_port=6379)
            print("✅ LiteLLM Router initialized successfully.")
        except Exception as e:
            print(f"❌ LiteLLM Router initialization failed: {e}")
            sys.exit(1)
    else:
        print("⚠️ LiteLLM not installed in this environment. Skipping deep validation, only YAML check performed.")

if __name__ == "__main__":
    test_config_initialization()
