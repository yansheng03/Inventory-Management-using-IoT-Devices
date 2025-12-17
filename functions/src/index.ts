// functions/src/index.ts

import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import { GoogleAuth } from "google-auth-library";

const CLOUD_RUN_URL =
  "https://inventory-ai-372541546387.asia-southeast1.run.app";

initializeApp();
const db = getFirestore();
const storage = getStorage();
const auth = new GoogleAuth();
let client: any;

interface AIResponse {
  added: { name: string; category: string }[];
  removed: { name: string; category: string }[];
}

// --- HELPER: Dice Coefficient for Similarity ---
// Returns a score from 0.0 to 1.0
function getSimilarity(str1: string, str2: string): number {
  const s1 = str1.replace(/\s+/g, "").toLowerCase();
  const s2 = str2.replace(/\s+/g, "").toLowerCase();

  if (s1 === s2) return 1.0;
  if (s1.length < 2 || s2.length < 2) return 0.0;

  const bigrams1 = new Map<string, number>();
  for (let i = 0; i < s1.length - 1; i++) {
    const bigram = s1.substring(i, i + 2);
    bigrams1.set(bigram, (bigrams1.get(bigram) || 0) + 1);
  }

  let intersection = 0;
  for (let i = 0; i < s2.length - 1; i++) {
    const bigram = s2.substring(i, i + 2);
    if (bigrams1.get(bigram) && bigrams1.get(bigram)! > 0) {
      intersection++;
      bigrams1.set(bigram, bigrams1.get(bigram)! - 1);
    }
  }

  return (2.0 * intersection) / (s1.length + s2.length - 2);
}

// --- 1. VIDEO PROCESSING FUNCTION ---
export const processInventoryVideo = onObjectFinalized(
  {
    bucket: "iot-inventory-management-7c555.firebasestorage.app",
    cpu: 2,
  },
  async (event) => {
    const filePath = event.data.name;
    logger.info(`Processing video: ${filePath}`);

    const pathParts = filePath.split("/");
    let userId = "";
    let deviceId = "";

    if (
      pathParts.length >= 5 &&
      pathParts[0] === "users" &&
      pathParts[2] === "devices"
    ) {
      userId = pathParts[1];
      deviceId = pathParts[3];
    } else if (pathParts.length >= 3 && pathParts[0] === "uploads") {
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
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ gcsPath: gcsUri }),
      });

      const result = response.data as AIResponse;
      const totalChanges = result.added.length + result.removed.length;

      logger.info(`Results: ${totalChanges} changes detected.`);

      const batch = db.batch();
      const inventoryRef = db.collection("inventory");
      const detectionTime = Timestamp.now();

      // 2. FETCH EXISTING ITEMS FOR FUZZY MATCHING
      const currentInventorySnap = await inventoryRef
        .where("source_device_id", "==", deviceId)
        .get();

      const existingItems = currentInventorySnap.docs.map((doc) => ({
        id: doc.id,
        ref: doc.ref,
        data: doc.data(),
      }));

      // Helper to find the best matching item in the database
      const findBestMatch = (aiName: string, aiCategory: string) => {
        let bestMatch = null;
        let highestScore = 0.0;
        const THRESHOLD = 0.65;

        for (const item of existingItems) {
          if (item.data.category !== aiCategory) continue;

          const score = getSimilarity(aiName, item.data.name);
          if (score > highestScore) {
            highestScore = score;
            bestMatch = item;
          }
        }
        return highestScore >= THRESHOLD ? bestMatch : null;
      };

      // 3. PROCESS ADDS
      for (const item of result.added) {
        const match = findBestMatch(item.name, item.category);

        if (!match) {
          const newDoc = inventoryRef.doc();
          batch.set(newDoc, {
            name: item.name,
            name_normalized: item.name.toLowerCase(),
            category: item.category,
            quantity: 1,
            lastDetected: detectionTime,
            source_device_id: deviceId,
            owner_id: userId,
          });
          existingItems.push({
            id: newDoc.id,
            ref: newDoc,
            data: { name: item.name, category: item.category, quantity: 1 },
          });
        } else {
          batch.update(match.ref, {
            quantity: FieldValue.increment(1),
            lastDetected: detectionTime,
          });
          match.data.quantity += 1;
        }
      }

      // 4. PROCESS REMOVALS
      for (const item of result.removed) {
        const match = findBestMatch(item.name, item.category);

        if (match) {
          const currentQty = match.data.quantity || 0;
          if (currentQty > 1) {
            batch.update(match.ref, { quantity: FieldValue.increment(-1) });
            match.data.quantity -= 1;
          } else {
            batch.delete(match.ref);
            const index = existingItems.indexOf(match);
            if (index > -1) existingItems.splice(index, 1);
          }
        } else {
          logger.warn(
            `Tried to remove '${item.name}' but could not find it in inventory.`
          );
        }
      }

      await batch.commit();
      logger.info("Database updated successfully using Fuzzy Matching.");
    } catch (err: any) {
      logger.error("Error processing:", err.message);
    }
  }
);

// --- 2. CLEANUP FUNCTION (Robust Metadata Check, >24 Hours) ---
export const cleanupOldVideos = onSchedule("every day 00:00", async (event) => {
  const bucket = storage.bucket(
    "iot-inventory-management-7c555.firebasestorage.app"
  );
  const MAX_AGE_MS = 24 * 60 * 60 * 1000;
  const now = Date.now();

  logger.info("Starting cleanup...");

  try {
    const [files] = await bucket.getFiles({ prefix: "users/" });
    let deletedCount = 0;

    for (const file of files) {
      const fileName = file.name.split("/").pop();
      if (!fileName || !fileName.endsWith(".avi")) continue;

      const [metadata] = await file.getMetadata();

      // --- FIX: Ensure timeCreated exists ---
      if (!metadata.timeCreated) {
        logger.warn(`Skipping ${fileName}: No creation time found.`);
        continue;
      }

      const timeCreated = new Date(metadata.timeCreated).getTime();
      const fileAge = now - timeCreated;

      if (fileAge > MAX_AGE_MS) {
        await file.delete();
        deletedCount++;
        logger.info(
          `Deleted ${fileName} (Age: ${(fileAge / 3600000).toFixed(1)}h)`
        );
      }
    }
    logger.info(`Cleanup complete. Deleted ${deletedCount} files.`);
  } catch (error) {
    logger.error("Error during cleanup:", error);
  }
});
