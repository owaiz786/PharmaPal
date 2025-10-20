💊 PharmPal: AI-Powered Pharmaceutical Inventory Management

PharmPal is an intelligent, full-stack platform that revolutionizes how pharmacies manage their medicine inventory.
It integrates AI, voice recognition, computer vision, and barcode scanning to automate and simplify the entire lifecycle of medicine tracking — from stock entry to real-time monitoring.

✨ Key Features
🧩 Multi-User Authentication

Secure registration and login system.

Each user’s data is isolated for privacy and security.

JWT-based authentication for reliable session management.

🔍 Multi-Modal Input System

PharmPal enables intuitive data entry using three complementary modes:

📦 Barcode/QR Code Scanning

Add or look up medicines instantly using the device camera.

Supports both standard barcodes and GS1 Smart QR codes, automatically extracting lot numbers, expiry dates, and batch details.

🎙️ Voice Commands

Add inventory using natural speech.
Example: “Add 100 units of Paracetamol 500 mg, expiry December 2026.”

Powered by OpenAI Whisper for transcription and a local LLM/NLU model for parsing.

📸 OCR from Images

Capture a photo of a medicine label to auto-fill details like name, expiry, and price.

Uses EasyOCR for on-device text extraction — no cloud dependency required.

📦 Real-Time Inventory Management

Add, edit, and delete medicines or batches effortlessly.

Manage individual batches with unique lot numbers and expiry tracking.

Real-time stock updates on dispensing and restocking.

Automatic removal of empty or expired batches.

🤖 AI-Powered Chatbot

Built-in assistant “PharmPal” understands natural language queries:

“How much Paracetamol is in stock?”

“Show medicines expiring in the next 30 days.”

“Restock list for the next order.”

Supports local or cloud-based inference via Groq, OpenAI, or DeepSeek models.

🎨 Modern Flutter UI

Clean, responsive, and intuitive interface with:

Navigation drawer

Pull-to-refresh

Swipe-to-delete

Light & dark mode support

Tailored for mobile-first experience using Material 3 design principles.

🏛️ Architecture Overview

PharmPal follows a decoupled client–server architecture:

Layer	Technology	Description
Frontend (Mobile App)	Flutter	Cross-platform UI for Android, iOS, and Web. Handles camera, voice input, and API calls.
Backend (API Server)	FastAPI (Python)	Handles authentication, CRUD operations, AI processing, and database communication.
Database	Neon PostgreSQL	Serverless, auto-scaling PostgreSQL database for secure, reliable data storage.
AI Services	Whisper · EasyOCR ·Groq	Power speech-to-text, OCR, and chatbot intelligence.
⚙️ 1. Backend Setup (FastAPI)
🧩 Clone the Repository
git clone <your-repository-url>
cd smart-pharma-dbms  # Backend project folder

📦 Install Dependencies
pip install -r requirements.txt

If no requirements.txt is available:

pip install "fastapi[all]" sqlalchemy psycopg2-binary passlib[bcrypt] python-jose python-dotenv \
easyocr openai-whisper transformers torch accelerate openai

🔐 Environment Variables

Create a .env file in the backend project root:

DATABASE_URL="postgresql://user:password@host:port/dbname"
SECRET_KEY="your_super_secret_jwt_key"
GROQ_API_KEY="gsk_your_groq_api_key"  # or OPENAI_API_KEY / DEEPSEEK_API_KEY

🚀 Run the FastAPI Server
uvicorn main:app --reload --host 0.0.0.0 --port 8000


⚠️ The first run will download models (Whisper, TinyLlama, etc.), which may take several minutes.

📱 2. Frontend Setup (Flutter)
Navigate to the Flutter App Folder
cd ../pharmaapp

Get Dependencies
flutter pub get

Configure API Endpoint

Find your local network IP address:

Windows: ipconfig

macOS/Linux: ifconfig

Update _baseUrl in lib/api_service.dart:

static const String _baseUrl = "http://192.168.1.10:8000";

Run the App
flutter run


Connect your device or emulator — you can now:

Register/login securely

Add medicines via barcode, voice, or OCR

Manage batches in real-time

Chat with PharmPal AI Assistant

🧠 AI Integration Options
Function	Default Library	Alternate Cloud Option
Speech-to-Text	Whisper (local)	OpenAI Whisper API
OCR	EasyOCR	Google Cloud Vision
Chatbot / NLU	TinyLlama (local)	Groq / DeepSeek / OpenAI

You can toggle between local and cloud AI modes in the .env configuration.

🧰 Tech Stack Summary
Category	Technology
Frontend	Flutter, Dart
Backend	FastAPI, Python
Database	PostgreSQL (Neon)
AI Models	Whisper, EasyOCR, TinyLlama, Transformers
Authentication	JWT, Passlib (bcrypt)
Deployment	Render / Railway / Vercel (optional)
🧪 Future Enhancements

🔄 Real-time synchronization across devices.

🧬 AI-driven demand forecasting for automatic reorder suggestions.

📊 Analytics dashboard for sales and expiry trends.

☁️ Cloud sync for backup and data federation.
