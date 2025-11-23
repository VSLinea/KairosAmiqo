import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const email = 'vsandu@test.com';
  console.log(`🔍 Looking for user ${email}...`);

  const user = await prisma.appUser.findFirst({
    where: { email },
  });

  if (!user) {
    console.error(`❌ User ${email} not found in database.`);
    process.exit(1);
  }

  console.log(`✅ Found user: ${user.id}`);

  console.log('🚀 Creating test negotiation...');

  const negotiation = await prisma.negotiation.create({
    data: {
      owner: user.id,
      title: 'Coffee Chat',
      state: 'awaiting_replies',
      intentCategory: 'social',
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days from now
      participants: {
        create: [
          {
            userId: user.id,
            status: 'organizer',
          },
        ],
      },
      proposedSlots: {
        create: [
          {
            slotIndex: 0,
            startsAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // Tomorrow
            durationMinutes: 60,
          },
          {
            slotIndex: 1,
            startsAt: new Date(Date.now() + 48 * 60 * 60 * 1000), // Day after tomorrow
            durationMinutes: 60,
          },
        ],
      },
      proposedVenues: {
        create: [
          {
            venueIndex: 0,
            venueName: 'Starbucks',
          },
        ],
      },
    },
  });

  console.log(`✅ Created negotiation: ${negotiation.id}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
