import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

def run_migrations():
    load_dotenv()
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        print("ERROR: DATABASE_URL not found")
        return

    sql_file = "app/database/migrations/001_initial_schema.sql"
    if not os.path.exists(sql_file):
        print(f"ERROR: SQL file not found: {sql_file}")
        return

    try:
        engine = create_engine(db_url)
        with open(sql_file, "r", encoding="utf-8") as f:
            content = f.read()
            # Split by semicolon to execute separate statements if needed, 
            # though execute(text(content)) usually works for Postgres
            with engine.connect() as conn:
                conn.execute(text(content))
                conn.commit()
                print("SUCCESS: Database schema initialized!")
    except Exception as e:
        print(f"ERROR: Migration failed: {e}")

if __name__ == "__main__":
    run_migrations()
