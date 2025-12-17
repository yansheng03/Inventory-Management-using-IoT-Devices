import os
import json
import mimetypes
from fastapi import FastAPI
from pydantic import BaseModel
from google.cloud import storage
import vertexai
from vertexai.generative_models import GenerativeModel, Part

app = FastAPI()

# Initialize Vertex AI
PROJECT_ID = "iot-inventory-management-7c555" 
LOCATION = "us-central1"
vertexai.init(project=PROJECT_ID, location=LOCATION)
 
model = GenerativeModel("gemini-2.5-flash")

class VideoRequest(BaseModel):
    gcsPath: str

@app.post("/analyze_movement")
async def analyze_movement(request: VideoRequest):
    print(f"Processing media with Gemini: {request.gcsPath}", flush=True)
    
    filename = request.gcsPath.split("/")[-1]
    local_filename = f"/tmp/{filename}"
    
    try:
        # 1. Determine MIME type
        mime_type, _ = mimetypes.guess_type(local_filename)
        if not mime_type:
            mime_type = "video/mp4" # Fallback

        # 2. Download File
        storage_client = storage.Client()
        path_clean = request.gcsPath.replace("gs://", "")
        bucket_name, blob_name = path_clean.split("/", 1)
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(blob_name)
        blob.download_to_filename(local_filename)

        # 3. Prepare the Prompt
        # explicit categories list
        categories = [
            "vegetables", "fruit", "meat", "seafood", "dairy", 
            "bakery", "leftovers", "drinks", "condiments", "others"
        ]
        
        prompt = f"""
        You are a smart fridge inventory manager. Analyze this media content carefully.
        
        Did an item enter the fridge (Added) or leave the fridge (Removed)? The item being tracked will mostly be held by a hand.
        Identify the specific item and categorize it into one of these exact categories:
        {categories}
        
        Rules:
        - If a hand puts an item IN, it is 'added'.
        - If a hand takes an item OUT, it is 'removed'.
        - If multiple items are added/removed (e.g., 2 Apples), you MUST list them as separate objects in the JSON array.
        - **NAMING FORMAT: [Brand Name] [Product Name]** (e.g., 'Maggi Chicken Stock').
        - **CLEANUP RULE: Remove packaging words.** (Do NOT use words like 'Box', 'Bottle', 'Can', 'Packet', '200g', 'Value Pack').
        - **CLEANUP RULE: Remove marketing adjectives.** (Do NOT use 'Delicious', 'Fresh', 'Premium').
        - Example: If 2 apples are added, the 'added' list should contain TWO objects: [{{"name": "Apple", ...}}, {{"name": "Apple", ...}}].
        - If nothing happens, return empty lists.
        - Ignore the hand itself. Focus on the object.

        Return ONLY raw JSON. Do not use Markdown formatting.
        The output must strictly follow this structure:
        {{
            "added": [{{"name": "Apple", "category": "fruit"}}], 
            "removed": [{{"name": "Milk", "category": "dairy"}}]
        }}
        """

        # 4. Read file data
        with open(local_filename, "rb") as f:
            file_data = f.read()

        media_part = Part.from_data(
            mime_type=mime_type,
            data=file_data
        )

        # 5. Ask the AI
        print("Sending to Gemini...", flush=True)
        response = model.generate_content(
            [media_part, prompt],
            generation_config={"response_mime_type": "application/json"}
        )
        
        print(f"Gemini Response: {response.text}", flush=True)

        # 6. Parse Result
        result_json = json.loads(response.text)
        return result_json

    except Exception as e:
        print(f"ERROR: {e}", flush=True)
        return {"added": [], "removed": [], "error": str(e)}
        
    finally:
        if os.path.exists(local_filename):
            os.remove(local_filename)