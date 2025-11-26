import os
import json
from fastapi import FastAPI
from pydantic import BaseModel
from google.cloud import storage
import vertexai
from vertexai.generative_models import GenerativeModel, Part

app = FastAPI()

# Initialize Vertex AI
# REPLACE with your actual Project ID if different
PROJECT_ID = "iot-inventory-management-7c555" 
LOCATION = "us-central1"
vertexai.init(project=PROJECT_ID, location=LOCATION)
 
model = GenerativeModel("gemini-2.5-flash")

class VideoRequest(BaseModel):
    gcsPath: str

@app.post("/analyze_movement")
async def analyze_movement(request: VideoRequest):
    print(f"Processing video with Gemini: {request.gcsPath}", flush=True)
    
    local_filename = "/tmp/video.mp4"
    
    try:
        # 1. Download Video
        storage_client = storage.Client()
        path_clean = request.gcsPath.replace("gs://", "")
        bucket_name, blob_name = path_clean.split("/", 1)
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(blob_name)
        blob.download_to_filename(local_filename)

        # 2. Prepare the Prompt
        prompt = """
        You are a smart fridge inventory manager. Watch this video carefully.
        
        Did an item enter the fridge (Added) or leave the fridge (Removed)?
        Identify the specific item (e.g., 'Apple', 'Chobani Yogurt', 'Egg').
        
        Rules:
        - If a hand puts an item IN, it is 'added'.
        - If a hand takes an item OUT, it is 'removed'.
        - If nothing happens, return empty lists.
        - Ignore the hand itself. Focus on the object.
        
        Return ONLY raw JSON. Do not use Markdown formatting.
        Format: {"added": ["item_name"], "removed": ["item_name"]}
        """

        # 3. Read video data
        with open(local_filename, "rb") as f:
            video_data = f.read()

        video_part = Part.from_data(
            mime_type="video/mp4",
            data=video_data
        )

        # 4. Ask the AI
        print("Sending to Gemini...", flush=True)
        response = model.generate_content(
            [video_part, prompt],
            generation_config={"response_mime_type": "application/json"}
        )
        
        print(f"Gemini Response: {response.text}", flush=True)

        # 5. Parse Result
        result_json = json.loads(response.text)
        return result_json

    except Exception as e:
        print(f"ERROR: {e}", flush=True)
        return {"added": [], "removed": [], "error": str(e)}
        
    finally:
        if os.path.exists(local_filename):
            os.remove(local_filename)