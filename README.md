# MediShield

Flutter client and Express/MongoDB API for MediShield.

## Run locally

1. Start MongoDB at `mongodb://127.0.0.1:27017/medishield`, or update `backend/.env` with your MongoDB connection string.
2. In `backend`, install dependencies with `npm install`, copy `.env.example` to `.env`, configure the required secrets and `OPENAI_API_KEY`, then start the API with `npm run dev`. Check `http://localhost:5000/health` for the health response.
3. In the project root, run `flutter pub get` and then `flutter run`.

The Flutter client defaults to `http://localhost:5000/api/v1` on desktop and web, and `http://10.0.2.2:5000/api/v1` on the Android emulator. For another API host, pass `--dart-define=API_BASE_URL=https://your-api-host/api/v1`.

## Prescription scanner services

Prescription OCR runs locally with Tesseract.js; PDFs are rendered page by page with PDF.js. No Azure account or Azure OCR key is required. The English OCR model is downloaded and cached on the backend computer the first time a scan is submitted, so the backend needs internet access for that initial download. Structured medicine extraction still uses the OpenAI Responses API and requires `OPENAI_API_KEY`; API usage may be billable. `OPENAI_MODEL` defaults to `gpt-4.1-mini`. The key stays on the backend and is never sent to the Flutter client.

The upload endpoint supports JPG, PNG, and PDF files up to 5 MB (PDFs are limited to 20 pages). It stores the OCR result and extracted fields on the existing `PrescriptionScan` record. The user must review and confirm the extracted medicines before the authenticated confirmation endpoint creates `Medicine` records. No medicines are generated when OCR or AI extraction fails. Each extraction contains a conservative confidence estimate; uncertain records are marked for user review.

Local OCR tries alternate right-angle page orientations when its first read has low confidence. OCR and AI extraction still depend on document quality; users should verify every medicine and schedule before saving. For production Android builds, serve the API over HTTPS.
