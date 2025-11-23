#!/usr/bin/env node
/**
 * Create Test Users in Firebase Auth
 * Creates 3 test accounts for P4.S2 verification
 * 
 * Usage: node create-test-users.mjs
 */

import admin from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Test users to create
const TEST_USERS = [
  { email: 'user_1@test.com', password: 'KairosTest1', displayName: 'Test User 1' },
  { email: 'user_2@test.com', password: 'KairosTest2', displayName: 'Test User 2' },
  { email: 'user_3@test.com', password: 'KairosTest3', displayName: 'Test User 3' },
];

async function main() {
  console.log('🔥 Creating Firebase test users...\n');

  // Initialize Firebase Admin SDK
  const credentialsPath = path.join(__dirname, '../firebase-admin.json');
  
  if (!fs.existsSync(credentialsPath)) {
    console.error(`❌ Firebase credentials not found at: ${credentialsPath}`);
    process.exit(1);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));
  
  if (admin.apps.length === 0) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }

  const auth = admin.auth();
  const results = {
    created: [],
    existing: [],
    errors: [],
  };

  // Create each test user
  for (const user of TEST_USERS) {
    try {
      console.log(`Creating user: ${user.email}...`);
      
      // Check if user already exists
      try {
        const existingUser = await auth.getUserByEmail(user.email);
        console.log(`  ℹ️  User already exists (UID: ${existingUser.uid})`);
        results.existing.push(user.email);
        continue;
      } catch (err) {
        // User doesn't exist, proceed to create
        if (err.code !== 'auth/user-not-found') {
          throw err;
        }
      }

      // Create the user
      const userRecord = await auth.createUser({
        email: user.email,
        password: user.password,
        displayName: user.displayName,
        emailVerified: true, // Auto-verify for test users
      });

      console.log(`  ✅ Created successfully (UID: ${userRecord.uid})`);
      results.created.push(user.email);

    } catch (error) {
      console.error(`  ❌ Error creating ${user.email}:`, error.message);
      results.errors.push({ email: user.email, error: error.message });
    }
  }

  // Summary
  console.log('\n📊 Summary:');
  console.log(`  ✅ Created: ${results.created.length}`);
  console.log(`  ℹ️  Already existed: ${results.existing.length}`);
  console.log(`  ❌ Errors: ${results.errors.length}`);

  if (results.created.length > 0) {
    console.log('\n✅ New users created:');
    results.created.forEach(email => console.log(`  - ${email}`));
  }

  if (results.existing.length > 0) {
    console.log('\nℹ️  Existing users (no action needed):');
    results.existing.forEach(email => console.log(`  - ${email}`));
  }

  if (results.errors.length > 0) {
    console.log('\n❌ Errors:');
    results.errors.forEach(({ email, error }) => console.log(`  - ${email}: ${error}`));
    process.exit(1);
  }

  console.log('\n🎉 Test user creation complete!');
  console.log('\nTest credentials:');
  TEST_USERS.forEach(({ email, password }) => {
    console.log(`  ${email} / ${password}`);
  });

  process.exit(0);
}

main().catch((error) => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
