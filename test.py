import psycopg2

try:
    conn = psycopg2.connect(
        dbname="neondb",
        user="neondb_owner",
        password="npg_NIHLgqWsP45B",
        host="ep-rapid-hill-ad8bzv0f-pooler.c-2.us-east-1.aws.neon.tech",
        port="5432",
        sslmode="require",
        channel_binding="require"
    )
    print("✅ Connected to Neon!")
except Exception as e:
    print("❌ Error:", e)
