import os

from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
SPOTIFY_CLIENT_ID = os.environ.get("SPOTIFY_CLIENT_ID", "")
SPOTIFY_CLIENT_SECRET = os.environ.get("SPOTIFY_CLIENT_SECRET", "")

USER_AGENT = "GenieUsBot/0.1 (+free community event discovery; non-commercial)"
REQUEST_DELAY_SECONDS = 2.0
REQUEST_TIMEOUT_SECONDS = 20

# Dedup thresholds (thefuzz 0-100)
DEDUP_AUTO_MERGE = 90
DEDUP_REVIEW_MIN = 75

LOCAL_TZ = "Asia/Kolkata"
