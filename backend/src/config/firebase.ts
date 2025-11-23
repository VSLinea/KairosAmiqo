import admin from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';
import { env } from './env.js';

let firebaseApp: admin.app.App | null = null;

function loadServiceAccount(): admin.ServiceAccount {
  const credentialsPath = path.isAbsolute(env.FIREBASE_CREDENTIALS_PATH)
    ? env.FIREBASE_CREDENTIALS_PATH
    : path.join(process.cwd(), env.FIREBASE_CREDENTIALS_PATH);

  if (!fs.existsSync(credentialsPath)) {
    throw new Error(
      `Firebase credentials file not found at: ${credentialsPath}. ` +
        'Check FIREBASE_CREDENTIALS_PATH in your .env file.'
    );
  }

  const fileContents = fs.readFileSync(credentialsPath, 'utf8');

  try {
    const parsed = JSON.parse(fileContents);
    return parsed as admin.ServiceAccount;
  } catch (err) {
    throw new Error(
      `Failed to parse Firebase credentials JSON at ${credentialsPath}: ${(err as Error).message}`
    );
  }
}

export function initializeFirebase(): admin.app.App {
  // Check module-level singleton
  if (firebaseApp) {
    return firebaseApp;
  }

  // Check if Firebase Admin SDK already has a default app
  // This handles the case where the app was initialized elsewhere
  try {
    const existingApp = admin.app();
    firebaseApp = existingApp;
    return firebaseApp;
  } catch (error) {
    // No existing app, proceed with initialization
  }

  const serviceAccount = loadServiceAccount();

  firebaseApp = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  return firebaseApp;
}

export function getFirebaseAuth(): admin.auth.Auth {
  if (!firebaseApp) {
    throw new Error('Firebase not initialized. Call initializeFirebase() first.');
  }
  return admin.auth(firebaseApp);
}
