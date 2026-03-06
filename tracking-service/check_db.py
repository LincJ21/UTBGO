import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

def check_db():
    load_dotenv(override=True)
    db_url = os.getenv("DATABASE_URL", "").strip().strip("'").strip('"')
    print(f"DEBUG: DATABASE_URL repr: {repr(db_url)}")
    print(f"DEBUG: DATABASE_URL hex: {db_url.encode().hex()}")
    if db_url:
        print(f"DEBUG: DATABASE_URL length: {len(db_url)}")
        # Mask password
        parts = db_url.split('@')
        if len(parts) > 1:
            print(f"DEBUG: Host: {parts[1]}")
    else:
        print("DEBUG: DATABASE_URL NOT FOUND")
        return

    try:
        engine = create_engine(db_url)
        with engine.connect() as conn:
            print("SUCCESS: Connected to database!")
            tables = ["tracking_events", "content_metrics", "content_watch_time"]
            for t in tables:
                res = conn.execute(text(f"SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = '{t}')"))
                print(f"Table '{t}': {'EXISTS' if res.scalar() else 'MISSING'}")
    except Exception as e:
        print(f"ERROR: Connection failed: {e}")

if __name__ == "__main__":
    check_db()
