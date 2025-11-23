import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';

dotenv.config();

const FIREBASE_CREDENTIALS_PATH = process.env.FIREBASE_CREDENTIALS_PATH ?? './firebase-admin.json';
const FIREBASE_WEB_API_KEY = process.env.FIREBASE_WEB_API_KEY;

if (!FIREBASE_WEB_API_KEY) {
  console.error('FIREBASE_WEB_API_KEY is not set. Add it to backend/.env or export it before running this script.');
  process.exit(1);
}

const keyPath = path.isAbsolute(FIREBASE_CREDENTIALS_PATH)
  ? FIREBASE_CREDENTIALS_PATH
  : path.join(process.cwd(), FIREBASE_CREDENTIALS_PATH.replace(/^\.\//, ''));

if (!fs.existsSync(keyPath)) {
  console.error(`Firebase credentials file not found at ${keyPath}`);
  process.exit(1);
}

const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

function parseArgs(argv) {
  const opts = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith('--')) continue;
    const key = arg.slice(2);
    const value = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : 'true';
    opts[key] = value;
    if (value !== 'true') {
      i += 1;
    }
  }
  return opts;
}

const options = parseArgs(process.argv.slice(2));
const email = options.email ?? 'mobile.tester@example.com';
const password = options.password ?? 'Test123!';
const displayName = options.displayName ?? 'Mobile Tester';

async function ensureUser() {
  try {
    const existing = await admin.auth().getUserByEmail(email);
    if (existing.displayName !== displayName) {
      await admin.auth().updateUser(existing.uid, { displayName });
    }
    return existing;
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      return await admin.auth().createUser({ email, password, displayName });
    }
    throw error;
  }
}

async function exchangeCustomToken(customToken) {
  const resp = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${FIREBASE_WEB_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true })
    }
  );

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Failed to exchange custom token: ${resp.status} ${text}`);
  }

  return resp.json();
}

async function main() {
  const user = await ensureUser();
  const customToken = await admin.auth().createCustomToken(user.uid);
  const session = await exchangeCustomToken(customToken);

  const output = {
    email,
    password,
    uid: user.uid,
    customToken,
    idToken: session.idToken,
    refreshToken: session.refreshToken,
    expiresInSeconds: session.expiresIn,
    firebaseProject: serviceAccount.project_id
  };

  console.log(JSON.stringify(output, null, 2));
}

main().catch((err) => {
  console.error('Error generating Firebase test credentials:', err);
  process.exit(1);
});
