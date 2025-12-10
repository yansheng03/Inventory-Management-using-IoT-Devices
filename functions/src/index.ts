import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { onObjectFinalized } from "firebase-functions/v2/storage"; 
import { onSchedule } from "firebase-functions/v2/scheduler"; 
import * as logger from "firebase-functions/logger";
import { GoogleAuth } from "google-auth-library"; 

const CLOUD_RUN_URL = "https://inventory-ai-372541546387.asia-southeast1.run.app"; 

initializeApp();
const db = getFirestore();
const storage = getStorage();
const auth = new GoogleAuth();
let client: any; 

// Interface definition
interface AIResponse {
    added: { name: string; category: string }[];
    removed: { name: string; category: string }[];
}

// --- 1. VIDEO PROCESSING FUNCTION (Kept Original Logic) ---
export const processInventoryVideo = onObjectFinalized({
    bucket: "iot-inventory-management-7c555.firebasestorage.app", 
    cpu: 2, 
  }, async (event) => {

  const filePath = event.data.name;
  logger.info(`Processing video: ${filePath}`);
  
  const pathParts = filePath.split("/");
  let userId = "";
  let deviceId = "";

  if (pathParts.length >= 5 && pathParts[0] === "users" && pathParts[2] === "devices") {
      userId = pathParts[1];
      deviceId = pathParts[3];
  } 
  else if (pathParts.length >= 3 && pathParts[0] === "uploads") {
      userId = pathParts[1];
      deviceId = pathParts[2];
  } else {
      logger.warn(`Skipping file with unexpected path structure: ${filePath}`);
      return;
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

    const batch = db.batch();
    const inventoryRef = db.collection("inventory");
    const detectionTime = Timestamp.now();
    const changeDetails: any[] = [];

    // PROCESS ADDS
    for (const item of result.added) {
        const normalizedName = item.name.toLowerCase();
        const category = item.category.toLowerCase();

        const q = inventoryRef
            .where("source_device_id", "==", deviceId)
            .where("name_normalized", "==", normalizedName)
            .where("category", "==", category)
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
             changeDetails.push({ id: newDoc.id, name: normalizedName, category: category, action: 'added' });
        } else {
             const doc = snapshot.docs[0];
             batch.update(doc.ref, {
                 quantity: FieldValue.increment(1),
                 lastDetected: detectionTime
             });
             changeDetails.push({ id: doc.id, name: normalizedName, category: category, action: 'added' });
        }
    }

    // PROCESS REMOVALS
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
             changeDetails.push({ id: doc.id, name: normalizedName, category: category, action: 'removed' });
        }
    }

    if (totalChanges > 3) {
        const alertRef = db.collection('batch_alerts').doc();
        batch.set(alertRef, {
            owner_id: userId,
            device_id: deviceId,
            timestamp: detectionTime,
            changes: changeDetails,
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

// --- 2. CLEANUP FUNCTION (Filename Based, >24 Hours) ---
export const cleanupOldVideos = onSchedule("every day 00:00", async (event) => {
    const bucket = storage.bucket("iot-inventory-management-7c555.firebasestorage.app");
    
    const MAX_AGE_MS = 24 * 60 * 60 * 1000; // 24 Hours
    const now = Date.now();

    logger.info("Starting filename-based cleanup...");

    try {
        // Scan the users folder
        const [files] = await bucket.getFiles({ prefix: 'users/' });
        let deletedCount = 0;

        for (const file of files) {
            const fileName = file.name.split('/').pop();
            if (!fileName) continue;

            // Extract Date from VID_YYYYMMDD_HHMMSS
            const match = fileName.match(/VID_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})/);

            if (match) {
                const year = parseInt(match[1]);
                const month = parseInt(match[2]) - 1; // Month is 0-indexed in JS
                const day = parseInt(match[3]);
                const hour = parseInt(match[4]);
                const minute = parseInt(match[5]);
                const second = parseInt(match[6]);

                const fileDate = new Date(year, month, day, hour, minute, second);
                const fileAge = now - fileDate.getTime();

                if (fileAge > MAX_AGE_MS) {
                    await file.delete();
                    deletedCount++;
                    logger.info(`Deleted ${fileName} (Age: ${(fileAge/3600000).toFixed(1)}h)`);
                }
            }
        }
        
        logger.info(`Cleanup complete. Deleted ${deletedCount} files.`);

    } catch (error) {
        logger.error("Error during cleanup:", error);
    }
});