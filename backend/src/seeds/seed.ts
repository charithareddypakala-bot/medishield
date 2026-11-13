import mongoose from 'mongoose';

import { Medicine } from '../models/Medicine';
import { User } from '../models/User';

const seedData = [
  {
    name: 'Siri Bethi',
    email: 'patient@medishield.com',
    phone: '+91 98765 43210',
    password: 'Patient@123',
    role: 'patient' as const,
  },
  {
    name: 'Asha Caretaker',
    email: 'caretaker@medishield.com',
    phone: '+91 91234 56789',
    password: 'Care@123',
    role: 'caretaker' as const,
  },
  {
    name: 'MediShield Admin',
    email: 'admin@medishield.com',
    phone: '+91 99887 66554',
    password: 'Admin@123',
    role: 'admin' as const,
  },
];

const medicines = [
  {
    name: 'Metformin',
    strength: '500 mg',
    purpose: 'Blood sugar control',
    schedule: '08:00 AM',
    instructions: 'Take with breakfast and water.',
    expiryDate: new Date(Date.now() + 1000 * 60 * 60 * 24 * 150).toISOString(),
    slot: 1,
    storageType: 'medicine_box',
    expiryWarning: false,
  },
  {
    name: 'Vitamin D3',
    strength: '60 IU',
    purpose: 'Bone health support',
    schedule: '12:30 PM',
    instructions: 'Take after lunch.',
    expiryDate: new Date(Date.now() + 1000 * 60 * 60 * 24 * 320).toISOString(),
    slot: 2,
    storageType: 'app_reminder',
    expiryWarning: false,
  },
];

const connectDb = async () => {
  const mongoUri = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/medishield';

  await mongoose.connect(mongoUri);
  console.log('Connected to MongoDB');
};

const seedUsers = async () => {
  for (const user of seedData) {
    const existing = await User.findOne({ email: user.email.toLowerCase() });

    if (!existing) {
      const created = await User.create(user);
      console.log(`Created ${created.role} user: ${created.email}`);
    } else {
      console.log(`User already exists: ${existing.email}`);
    }
  }
};

const seedMedicines = async () => {
  const patient = await User.findOne({ email: 'patient@medishield.com' });

  if (!patient) {
    return;
  }

  const existingMedicines = await Medicine.countDocuments({ userId: patient._id });

  if (existingMedicines > 0) {
    console.log('Medicines already seeded for patient');
    return;
  }

  const createdMedicines = await Medicine.insertMany(
    medicines.map((medicine) => ({
      ...medicine,
      user: patient._id,
    })),
  );

  console.log(`Created ${createdMedicines.length} medicines for patient`);
};

const seedDatabase = async () => {
  await connectDb();
  await seedUsers();
  await seedMedicines();
  await mongoose.disconnect();
  console.log('Seed completed successfully');
};

seedDatabase().catch((error) => {
  console.error('Seed failed', error);
  process.exit(1);
});
