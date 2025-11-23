import { initializeFirebase, getFirebaseAuth } from '../src/config/firebase.js';
import { env } from '../src/config/env.js';

// Initialize Firebase
initializeFirebase();
const auth = getFirebaseAuth();

const testUsers = [
  { email: 'user_1@test.com', password: 'KairosTest1', uid: 'test-user-1', displayName: 'Test User 1' },
  { email: 'user_2@test.com', password: 'KairosTest2', uid: 'test-user-2', displayName: 'Test User 2' },
  { email: 'user_3@test.com', password: 'KairosTest3', uid: 'test-user-3', displayName: 'Test User 3' },
];

async function createUsers() {
  console.log('🚀 Creating test users...');

  for (const user of testUsers) {
    try {
      // Check if user exists
      try {
        await auth.getUser(user.uid);
        console.log(`✅ User ${user.email} already exists.`);
        // Update password just in case
        await auth.updateUser(user.uid, {
          password: user.password,
          displayName: user.displayName,
          emailVerified: true,
        });
        console.log(`   Updated password/profile for ${user.email}`);
      } catch (error: any) {
        if (error.code === 'auth/user-not-found') {
          // Create user
          await auth.createUser({
            uid: user.uid,
            email: user.email,
            password: user.password,
            displayName: user.displayName,
            emailVerified: true,
          });
          console.log(`✅ Created user ${user.email}`);
        } else {
          throw error;
        }
      }
    } catch (error) {
      console.error(`❌ Failed to process user ${user.email}:`, error);
    }
  }

  console.log('✨ Done!');
  process.exit(0);
}

createUsers();
