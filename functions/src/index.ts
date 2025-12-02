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

// Define interface for the new AI response
interface AIResponse {
    added: { name: string; category: string }[];
    removed: { name: string; category: string }[];
}

export const processInventoryVideo = onObjectFinalized({
    bucket: "iot-inventory-management-7c555.firebasestorage.app", 
    cpu: 2, 
  }, async (event) => {

  const filePath = event.data.name; 
  // ... (Keep existing trigger/folder logic if you are using the sequence approach) ...
  // For standard single file:
  const contentType = event.data.contentType;
  logger.info(`Processing file: ${filePath} (${contentType})`);

  // 1. Determine User/Device (Same as before)
  const metadata = event.data.metadata || {};
  let userId = metadata.userId;
  let deviceId = metadata.deviceId;

  if (!userId || !deviceId) {
      const pathParts = filePath.split("/");
      if (pathParts.length >= 4 && pathParts[0] === "uploads") {
          userId = userId || pathParts[1];
          deviceId = deviceId || pathParts[2];
      }
  }
  userId = userId || "unknown_user";
  deviceId = deviceId || "unknown_device";

  const bucketName = event.data.bucket;
  const gcsUri = `gs://${bucketName}/${filePath}`;

  try {
    if (!client) client = await auth.getIdTokenClient(CLOUD_RUN_URL);
    
    const response = await client.request({
      url: `${CLOUD_RUN_URL}/analyze_movement`,
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({ gcsPath: gcsUri }),
    });

    const result = response.data as AIResponse;
    const totalChanges = result.added.length + result.removed.length;
    
    logger.info(`Results: ${totalChanges} changes detected.`);

    // 3. Database Updates
    const batch = db.batch();
    const inventoryRef = db.collection("inventory");
    const detectionTime = Timestamp.now();
    
    // We will track details for the alert
    const changeDetails: any[] = [];

    // --- PROCESS ADDS ---
    for (const item of result.added) {
        const normalizedName = item.name.toLowerCase();
        // Use the AI provided category
        const category = item.category.toLowerCase();

        const q = inventoryRef
            .where("source_device_id", "==", deviceId)
            .where("name_normalized", "==", normalizedName)
            .where("category", "==", category) // Match strictly on category too
            .limit(1);
        const snapshot = await q.get();

        if (snapshot.empty) {
             const newDoc = inventoryRef.doc();
             batch.set(newDoc, {
                 name: normalizedName,
                 name_normalized: normalizedName,
                 category: category,
                 quantity: 1,
                 lastDetected: detectionTime,
                 source_device_id: deviceId,
                 owner_id: userId
             });
             changeDetails.push({ 
                 id: newDoc.id, 
                 name: normalizedName, 
                 category: category, 
                 action: 'added' 
             });
        } else {
             const doc = snapshot.docs[0];
             batch.update(doc.ref, {
                 quantity: FieldValue.increment(1),
                 lastDetected: detectionTime
             });
             changeDetails.push({ 
                 id: doc.id, 
                 name: normalizedName, 
                 category: category, 
                 action: 'added' 
             });
        }
    }

    // --- PROCESS REMOVALS ---
    for (const item of result.removed) {
        const normalizedName = item.name.toLowerCase();
        const category = item.category.toLowerCase();

        const q = inventoryRef
            .where("source_device_id", "==", deviceId)
            .where("name_normalized", "==", normalizedName)
            .where("category", "==", category)
            .limit(1);
        const snapshot = await q.get();

        if (!snapshot.empty) {
             const doc = snapshot.docs[0];
             const currentQty = doc.data().quantity || 0;
             if (currentQty > 1) {
                 batch.update(doc.ref, { quantity: FieldValue.increment(-1) });
             } else {
                 batch.update(doc.ref, { quantity: 0 }); 
             }
             changeDetails.push({ 
                 id: doc.id, 
                 name: normalizedName, 
                 category: category, 
                 action: 'removed' 
             });
        }
    }

    // --- NEW: CHECK FOR BATCH ALERT ---
    if (totalChanges > 3) {
        const alertRef = db.collection('batch_alerts').doc();
        batch.set(alertRef, {
            owner_id: userId,
            device_id: deviceId,
            timestamp: detectionTime,
            changes: changeDetails, // Store what happened so user can review
            status: 'pending' 
        });
        logger.info(`Batch Alert created: ${alertRef.id}`);
    }

    await batch.commit();
    logger.info("Database updated successfully.");

  } catch (err: any) {
    logger.error("Error processing:", err.message);
  }
});