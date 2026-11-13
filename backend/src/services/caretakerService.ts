import { CaretakerLink } from '../models/CaretakerLink';
import { User } from '../models/User';
import { AppError } from '../utils/AppError';

const findUserByAccountReference = (value: string) => {
  const reference = value.trim();
  return /^[a-f\d]{24}$/i.test(reference)
    ? User.findById(reference)
    : User.findOne({ email: reference.toLowerCase() });
};

export const createCaretakerLinkRequest = async (payload: {
  patientId: string;
  caretakerId: string;
  message?: string;
}) => {
  const [patient, caretaker] = await Promise.all([
    findUserByAccountReference(payload.patientId),
    findUserByAccountReference(payload.caretakerId),
  ]);

  if (!patient) throw new AppError('Patient account not found. Check the email or account ID.', 404);
  if (!caretaker) throw new AppError('Caretaker account not found. Check the email or account ID.', 404);
  if (patient.role !== 'patient') throw new AppError('The selected patient account is not registered as a patient.', 400);
  if (caretaker.role !== 'caretaker') throw new AppError('The selected caretaker account is not registered as a caretaker.', 400);

  const existing = await CaretakerLink.findOne({
    patient: patient._id,
    caretaker: caretaker._id,
    status: { $in: ['pending', 'approved'] },
  });

  if (existing) throw new AppError('A pending or approved patient link already exists.', 409);

  const link = await CaretakerLink.create({
    patient: patient._id,
    caretaker: caretaker._id,
    patientEmail: patient.email,
    caretakerEmail: caretaker.email,
    status: 'pending',
    message: payload.message,
  });

  return link;
};

export const getCaretakerRequests = async (userId: string, role: 'patient' | 'caretaker' | 'admin') => {
  const query = role === 'patient' ? { patient: userId } : { caretaker: userId };

  const items = await CaretakerLink.find({ ...query, isDeleted: false }).sort({ createdAt: -1 }).lean();

  return items;
};

export const approveCaretakerRequest = async (requestId: string, patientUserId: string) => {
  const request = await CaretakerLink.findOne({ _id: requestId, patient: patientUserId, isDeleted: false });

  if (!request) {
    throw new AppError('Caretaker request not found', 404);
  }

  request.status = 'approved';
  await request.save();

  return request;
};

export const rejectCaretakerRequest = async (requestId: string, patientUserId: string) => {
  const request = await CaretakerLink.findOne({ _id: requestId, patient: patientUserId, isDeleted: false });

  if (!request) {
    throw new AppError('Caretaker request not found', 404);
  }

  request.status = 'rejected';
  await request.save();

  return request;
};

export const getApprovedPatientsForCaretaker = async (caretakerId: string) => {
  const links = await CaretakerLink.find({
    caretaker: caretakerId,
    status: 'approved',
    isDeleted: false,
  }).populate('patient', 'name email phone role');

  return links;
};
