import { buildApp } from '../src/app.js';

function createDevToken() {
  const uid = `dev-user-${Date.now()}`;
  const payload = { uid, name: 'Dev Tester', email: `${uid}@users.kairos.local` };
  const base64 = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return { token: `ignored.${base64}.ignored`, uid };
}

async function main() {
  const app = await buildApp();
  try {
    const { token, uid } = createDevToken();
    const response = await app.inject({
      method: 'GET',
      url: '/me',
      headers: {
        authorization: `Bearer ${token}`,
        'accept-language': 'fr-CA',
      },
    });

    console.log('User UID:', uid);
    console.log('Status:', response.statusCode);
    console.log('Body:', response.body);
  } finally {
    await app.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
