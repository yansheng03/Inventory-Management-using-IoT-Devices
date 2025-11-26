// functions/src/index.ts

// ... (Imports same as before)
import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp, FieldValue } from "firebase-admin/firestore";
import { onObjectFinalized } from "firebase-functions/v2/storage"; 
import * as logger from "firebase-functions/logger";
import { GoogleAuth } from "google-auth-library"; 

const CLOUD_RUN_URL = "https://inventory-ai-372541546387.asia-southeast1.run.app"; 

initializeApp();
const db = getFirestore();
const auth = new GoogleAuth();
let client: any; 

export const processInventoryVideo = onObjectFinalized({
    bucket: "iot-inventory-management-7c555.firebasestorage.app", 
    cpu: 2, // Give it a bit more power
  }, async (event) => {

  const filePath = event.data.name;

  logger.info(`Processing video: ${filePath}`);
  
  // 1. Parse Device ID
  const pathParts = filePath.split("/");
  // Assuming uploads/{userId}/{deviceId}/video.mjpeg
  if (pathParts.length < 4) return;
  
  const userId = pathParts[1];
  const deviceId = pathParts[2];

  const bucketName = event.data.bucket;
  const gcsUri = `gs://${bucketName}/${filePath}`;

  // 2. Call Cloud Run (The new Endpoint)
  try {
    if (!client) client = await auth.getIdTokenClient(CLOUD_RUN_URL);
    
    const response = await client.request({
      url: `${CLOUD_RUN_URL}/analyze_movement`, // NEW ENDPOINT
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({ gcsPath: gcsUri }),
    });

    const result = response.data as { added: string[], removed: string[] };
    logger.info(`Tracking Results: Added=${result.added}, Removed=${result.removed}`);

    // 3. Update Database
    const batch = db.batch();
    const inventoryRef = db.collection("inventory");
    const detectionTime = Timestamp.now();

    // --- PROCESS ADDS ---
    for (const name of result.added) {
        const normalizedName = name.toLowerCase();
        // Query for existing item
        const q = inventoryRef
            .where("source_device_id", "==", deviceId)
            .where("name_normalized", "==", normalizedName)
            .where("category", "==", "uncategorized")
            .limit(1);
        const snapshot = await q.get();

        if (snapshot.empty) {
             // Create new
             const newDoc = inventoryRef.doc();
             batch.set(newDoc, {
                 name: normalizedName,
                 name_normalized: normalizedName,
                 category: "uncategorized",
                 quantity: 1,
                 lastDetected: detectionTime,
                 source_device_id: deviceId,
                 owner_id: userId
             });
        } else {
             // Increment
             const doc = snapshot.docs[0];
             batch.update(doc.ref, {
                 quantity: FieldValue.increment(1),
                 lastDetected: detectionTime
             });
        }
    }

    // --- PROCESS REMOVALS ---
    for (const name of result.removed) {
        const normalizedName = name.toLowerCase();
        const q = inventoryRef
            .where("source_device_id", "==", deviceId)
            .where("name_normalized", "==", normalizedName)
            .where("category", "==", "uncategorized")
            .limit(1);
        const snapshot = await q.get();

        if (!snapshot.empty) {
             const doc = snapshot.docs[0];
             const currentQty = doc.data().quantity || 0;
             if (currentQty > 1) {
                 batch.update(doc.ref, { quantity: FieldValue.increment(-1) });
             } else {
                 // If quantity is 1, delete it? Or set to 0?
                 batch.update(doc.ref, { quantity: 0 }); 
             }
        }
    }

    await batch.commit();
    logger.info("Database updated successfully.");

  } catch (err: any) {
    logger.error("Error in video processing:", err.message);
  }
});