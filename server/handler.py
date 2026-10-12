"""
RunPod Serverless Handler — PeopleGone Phase 0 Worker
Exposes the processing pipeline to RunPod Serverless.
"""

import base64
import os
import requests
from typing import Dict, Any
from worker.pipeline import process

def download_image(url: str) -> bytes:
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    return response.content

def handler(job: Dict[str, Any]) -> Dict[str, Any]:
    """
    RunPod handler function.
    Job input schema:
    {
        "image_base64": "<base64_string>",  # OR
        "image_url": "https://...",
        "keep": [0, 1]                      # optional keeper indices
    }
    """
    job_input = job.get("input", {})
    keep = job_input.get("keep")

    # 1. Resolve photo bytes
    if "image_base64" in job_input:
        photo_bytes = base64.b64decode(job_input["image_base64"])
    elif "image_url" in job_input:
        try:
            photo_bytes = download_image(job_input["image_url"])
        except Exception as e:
            return {"error": f"Failed to download image from image_url: {str(e)}"}
    else:
        return {"error": "Missing image_base64 or image_url in job input"}

    # 2. Run pipeline
    try:
        result_bytes, metadata = process(photo_bytes, keep=keep)
        if metadata.get("fallbacks_used"):
            print("!" * 70)
            print(f">>> LOUD WARNING: FALLBACK MODE ACTIVE IN RUNPOD HANDLER: {metadata['fallbacks_used']} <<<")
            print("!" * 70)
        result_base64 = base64.b64encode(result_bytes).decode("utf-8")
        return {
            "status": "success",
            "result_base64": result_base64,
            "metadata": metadata
        }
    except Exception as e:
        return {
            "status": "error",
            "error": str(e)
        }

if __name__ == "__main__":
    try:
        import runpod
        runpod.serverless.start({"handler": handler})
    except ImportError:
        print("RunPod SDK not installed in current environment. Running in mock local mode.")
