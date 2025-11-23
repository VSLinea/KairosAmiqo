import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword, createUserWithEmailAndPassword, deleteUser } from 'firebase/auth';
import fetch from 'node-fetch';

// --- Configuration ---
const API_URL = 'http://127.0.0.1:3000';
const FIREBASE_CONFIG = {
  apiKey: process.env.FIREBASE_WEB_API_KEY || "AIzaSyB5cUx03al_ObPiJksG22ses_xD4OhH1XQ", // Fallback to what I saw in .env
  authDomain: "kairos-amiqo.firebaseapp.com", // Guessing based on project ID usually, but for auth only apiKey matters mostly for REST
  projectId: "kairos-amiqo",
};

// Initialize Firebase Client SDK (simulating iOS app)
const app = initializeApp(FIREBASE_CONFIG);
const auth = getAuth(app);

async function log(step: string, message: string, success: boolean) {
  const icon = success ? '✅' : '❌';
  console.log(`${icon} [${step}] ${message}`);
}

async function testEndpoint(name: string, url: string, token: string, expectedStatus = 200) {
  try {
    const res = await fetch(`${API_URL}${url}`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });
    
    if (res.status === expectedStatus) {
      const data = await res.json();
      log(name, `Status ${res.status}`, true);
      return data;
    } else {
      const text = await res.text();
      log(name, `Failed: Status ${res.status} - ${text}`, false);
      return null;
    }
  } catch (e) {
    log(name, `Exception: ${e}`, false);
    return null;
  }
}

async function auditExistingUser() {
  console.log('\n--- Auditing Existing User (vsandu@test.com) ---');
  const email = 'vsandu@test.com';
  const password = 'KairosTest1';

  try {
    // 1. Login with Firebase
    const userCredential = await signInWithEmailAndPassword(auth, email, password);
    const user = userCredential.user;
    const token = await user.getIdToken();
    log('Firebase Login', `Logged in as ${user.uid}`, true);

    // 2. Call /me (Triggers ensureAppUser if missing)
    const meData = await testEndpoint('GET /me', '/me', token);
    if (meData) {
        console.log('   User ID:', meData.data.id);
    }

    // 3. Call /negotiations (Should have the seeded data)
    const negData = await testEndpoint('GET /negotiations', '/negotiations', token);
    if (negData && negData.data) {
        console.log(`   Found ${negData.data.length} negotiations.`);
        if (negData.data.length > 0) {
            log('Data Check', 'Negotiations found', true);
        } else {
            log('Data Check', 'No negotiations found (unexpected after seed)', false);
        }
    }

  } catch (e) {
    log('Existing User Flow', `Failed: ${e}`, false);
  }
}

async function auditNewUser() {
  console.log('\n--- Auditing New User Signup ---');
  const timestamp = Date.now();
  const email = `audit_user_${timestamp}@test.com`;
  const password = 'TestPassword123!';

  try {
    // 1. Signup with Firebase
    const userCredential = await createUserWithEmailAndPassword(auth, email, password);
    const user = userCredential.user;
    const token = await user.getIdToken();
    log('Firebase Signup', `Created user ${user.uid} (${email})`, true);

    // 2. Call /me (Should create user in Postgres)
    const meData = await testEndpoint('GET /me (First Call)', '/me', token);
    if (meData) {
        log('User Creation', `User created in DB with ID: ${meData.data.id}`, true);
    }

    // 3. Call /negotiations (Should be empty)
    const negData = await testEndpoint('GET /negotiations', '/negotiations', token);
    if (negData && negData.data && negData.data.length === 0) {
        log('Data Check', 'Negotiations list is empty (expected)', true);
    } else {
        log('Data Check', `Unexpected data: ${JSON.stringify(negData)}`, false);
    }

    // Cleanup (Optional, but good practice)
    // await deleteUser(user); 
    // log('Cleanup', 'Deleted test user from Firebase', true);

  } catch (e) {
    log('New User Flow', `Failed: ${e}`, false);
  }
}

async function main() {
  console.log('🚀 Starting Auth Audit Script');
  await auditExistingUser();
  await auditNewUser();
  console.log('\n🏁 Audit Complete');
  process.exit(0);
}

main();
