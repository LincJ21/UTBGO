import redis
import os
from dotenv import load_dotenv

# Load from project root (parent of /tests)
env_path = os.path.join(os.path.dirname(__file__), '..', '.env')
if os.path.exists(env_path):
    load_dotenv(env_path)
else:
    load_dotenv(".env")

def test_upstash_connectivity():
    redis_url = os.getenv("REDIS_URL")
    if not redis_url:
        print("❌ REDIS_URL not found in .env")
        return

    print(f"Testing connectivity to: {redis_url.split('@')[1]}")
    try:
        # Use simple redis client
        client = redis.Redis.from_url(redis_url, socket_timeout=5)
        
        # Test PING
        if client.ping():
            print("✅ Successfully connected to Upstash Redis!")
            
            # Test Write/Read
            client.set("utbgo:health_check", "online")
            val = client.get("utbgo:health_check")
            if val and val.decode() == "online":
                print("✅ Write/Read test successful!")
            else:
                print("❌ Write/Read test failed.")
        else:
            print("❌ PING failed.")
            
    except Exception as e:
        print(f"❌ Connection error: {str(e)}")

if __name__ == "__main__":
    test_upstash_connectivity()
