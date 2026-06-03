import boto3
import os
from pathlib import Path
from config import BASE_DIR

s3 = boto3.client("s3")

def ensure_parent(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)


def download_file(key: str):
    local_path = BASE_DIR / key
    ensure_parent(local_path)

    s3.download_file(os.getenv("S3_MODEL_BUCKET"), key, str(local_path))


def delete_file(key: str):
    local_path = BASE_DIR / key
    if local_path.exists():
        local_path.unlink()
