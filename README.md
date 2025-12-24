# FIT: Fridge Inventory Tracker

FIT is an intelligent IoT-based inventory management system designed to automate kitchen tracking. By combining an ESP32-CAM, Google Vertex AI (Gemini), Firebase, and a Flutter mobile app, FIT automatically detects when items are added or removed from your fridge and categorizes them in real-time.

Features

Automated Tracking: Detects motion and records video/images of items entering or leaving the fridge.
AI-Item Detection: Uses Google Gemini 2.5 Flash to identify food items and determine the action (Added vs. Removed).
Categorization: Automatically sorts items into categories like Fruit, Vegetables, Dairy, Seafood, etc.
Batch Alerts: If multiple items are changed at once, the app triggers a review popup to ensure accuracy.
Multi-User & Security: Secure login/signup with strict data ownership rules (users only see their own items).
Cost & Waste Control: Helps prevent food waste and saves money by tracking what you have.
Cross-Platform App: Mobile interface built with Flutter (Android/iOS).

System Architecture
The following diagram illustrates the data flow from the hardware sensor to the user application.

    A[ESP32-CAM] -->|Uploads Video| B[Firebase Storage]
    B -->|Triggers| C[Firebase Cloud Functions]
    C -->|Sends Video URI| D[Cloud Run (Python/FastAPI)]
    D -->|Calls| E[Vertex AI (Gemini)]
    E -->|Returns JSON Analysis| D
    D -->|Returns Data| C
    C -->|Updates| F[Firestore Database]
    G[Flutter App] <-->|Reads/Writes| F
    G -->|Auth| H[Firebase Auth]

Repository Structure
ai_service/: Python FastAPI backend that interfaces with Google Vertex AI.
functions/: TypeScript Cloud Functions to handle storage triggers and database updates.
lib/: Flutter mobile application source code.

Prerequisites
Hardware:
ESP32-CAM module (AI-Thinker model recommended)
HC-SR501 PIR Motion Sensor
Power Supply (Recommended to use 5V/3V power adapter for breadboards or Battery) 
MicroSD Card for buffering video
Breadboard
Jumper Wire

<img width="720" height="720" alt="image" src="https://github.com/user-attachments/assets/2db71c47-b92a-4ff1-881b-9579301e8438" />

Software & Tools:
Flutter SDK: Required to build and run the mobile app.
Node.js & npm: Required to deploy Firebase Cloud Functions.
Python 3.9+: Required to run/deploy the AI Service.
Arduino IDE: Required to upload code to the ESP32-CAM.
Google Cloud CLI: For deploying Cloud Run services.
Firebase CLI: For deploying Functions, Rules, and managing the project.

# Step 1: Google Cloud & Firebase Setup
Create a Project: Go to the Firebase Console and create a new project.

Enable APIs:
Go to the Google Cloud Console.
Enable Vertex AI API, Cloud Run API, Cloud Build API, Artifact Registry API, and Cloud Functions API.

Firebase Services:
Authentication: Enable "Email/Password" sign-in provider.
Firestore: Create a database in production mode.
Storage: Create a default storage bucket.

# Step 2: AI Backend Setup (Cloud Run)
This service processes videos using Gemini.
Navigate to the directory:
cd ai_service
Update main.py: Replace PROJECT_ID with your actual Google Cloud Project ID.

Build and Deploy:
1. Submit Build
gcloud builds submit --tag gcr.io/*YOUR_PROJECT_ID*/inventory-ai-service .

2. Deploy Service (Copy the Service URL for the next step)
gcloud run deploy inventory-ai-service --image gcr.io/*YOUR_PROJECT_ID*/inventory-ai-service --platform managed --region *YOUR REGION* --no-allow-unauthenticated

# Step 3: Firebase Functions Setup
This connects Firebase Storage uploads to your AI Service.

Navigate to the directory:
cd functions
Install dependencies:
npm install

Update src/index.ts:
Set CLOUD_RUN_URL to the URL you got from Step 2.
Ensure the bucket name matches your Firebase Storage bucket.

Deploy Functions & Rules:
firebase deploy
Grant Permission: Allow your Cloud Function to talk to Cloud Run.
Find your project number: gcloud projects describe YOUR_PROJECT_ID

Run:
gcloud run services add-iam-policy-binding inventory-ai-service --member="serviceAccount:*YOUR_PROJECT_NUMBER*-compute@developer.gserviceaccount.com" --role="roles/run.invoker" --region=asia-southeast1


# Step 4: Hardware Setup (ESP32)
Open file in Arduino IDE to upload.
Install Libraries:
FirebaseClient (by Mobizt)
ESP32 board definitions (by Espressif)
Update Configuration:
Set FIREBASE_USER_EMAIL and PASSWORD (create a dummy account in Firebase Auth for the camera).
Set API_KEY
Set STORAGE_BUCKET.

Usage: On first boot, if Wi-Fi fails, it starts a BLE server named "InventoryFridge-Setup". Use the mobile app to connect and provision Wi-Fi.

# Step 5: Mobile App Setup (Flutter)
Navigate to the app folder:

Install Dependencies:
flutter pub get

Run the App:
flutter run

📱 App Usage
Register: Create an account in the app.
Connect Device: Go to the "Device" tab, scan for your ESP32 via BLE, and pass your Wi-Fi credentials.
Track: Place items in front of the camera. The app will update automatically.
Review: If many items change at once (>3), a "Batch Update" popup will appear for you to confirm the changes.

AI/ML: Python, FastAPI, Google Vertex AI (Gemini).

Embedded: C++, Arduino Framework, ESP32-CAM.
