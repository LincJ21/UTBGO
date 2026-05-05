import os
from dotenv import load_dotenv
from app.core.config import settings

def main():
    # Force load using the same logic as config.py
    env_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env')
    print(f"DEBUG: Loading .env from {env_path}")
    load_dotenv(dotenv_path=env_path, override=True)
    
    print(f"DEBUG: os.environ['API_KEY'] = {repr(os.getenv('API_KEY'))}")
    print(f"DEBUG: os.environ['RECOMMENDATIONS_API_KEY'] = {repr(os.getenv('RECOMMENDATIONS_API_KEY'))}")
    print(f"DEBUG: settings.API_KEY = {repr(settings.API_KEY)}")
    print(f"DEBUG: settings.DATABASE_URL (masked) = {settings.DATABASE_URL[:20]}...")

if __name__ == "__main__":
    main()
