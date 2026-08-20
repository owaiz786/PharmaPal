# 💊 PharmaPal - AI-Powered Pharmaceutical Inventory Management

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.8+-blue.svg)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.104+-green.svg)](https://fastapi.tiangolo.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-blue.svg)](https://postgresql.org)
[![Groq](https://img.shields.io/badge/Groq-LLM-orange.svg)](https://groq.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**AI-powered pharmaceutical inventory management with OCR, voice, and chatbot intelligence — pairing a FastAPI backend with a cross-platform Flutter app.**

[🚀 Quick Start](#-getting-started) · [📱 Flutter App](#-flutter-app) · [📡 API Reference](#-backend-api-reference) · [🤖 AI Features](#-ai-features)

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Key Features](#-key-features)
- [Data Model](#-data-model)
- [Backend API Reference](#-backend-api-reference)
- [Flutter App](#-flutter-app)
- [AI Features](#-ai-features)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [Security Notes](#-security-notes)
- [Deployment](#-deployment)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 Overview

**PharmaPal** is a comprehensive pharmaceutical inventory management system designed for pharmacies and small dispensaries. It combines:

- **🔐 Secure Multi-User System**: Every user's inventory is private and isolated
- **🤖 Three AI-Powered Intake Paths**: OCR, voice, and chatbot
- **📱 Cross-Platform App**: Flutter app for Android, iOS, Web, Windows, macOS, Linux
- **⚡ Smart Inventory Management**: Batch-level tracking with GS1 barcode scanning
- **🧠 AI Chatbot**: Natural language inventory queries with function calling

### Why PharmaPal?

| Problem | Traditional Solution | PharmaPal Solution |
|---------|---------------------|-------------------|
| **Manual Data Entry** | Slow, error-prone typing | **AI-powered OCR, voice, and chat** |
| **Inventory Tracking** | Single quantity per item | **Batch-level tracking with expiry dates** |
| **Staff Training** | Complex systems requiring training | **Natural language interface** |
| **Platform Access** | Desktop-only | **Cross-platform mobile + desktop** |
| **Data Isolation** | Shared data, privacy risks | **User-scoped private inventory** |

---

## 🏗️ Architecture

```mermaid
graph TB
    subgraph Frontend["Flutter App (Cross-Platform)"]
        A[Android/iOS/Web]
        B[Windows/macOS/Linux]
    end
    
    subgraph Backend["FastAPI Backend (Python)"]
        C[Auth Layer]
        D[Medicine API]
        E[Inventory API]
        F[OCR Service]
        G[Voice Service]
        H[Chatbot Service]
    end
    
    subgraph AI["AI Services"]
        I[EasyOCR]
        J[Whisper Tiny.en]
        K[Groq LLM]
    end
    
    subgraph Database["PostgreSQL"]
        L[(Users)]
        M[(Medicines)]
        N[(Inventory)]
        O[(Categories)]
        P[(Manufacturers)]
    end
    
    A --> C
    B --> C
    C --> D
    C --> E
    D --> F
    D --> G
    E --> H
    
    F --> I
    G --> J
    H --> K
    
    D --> L
    D --> M
    E --> N
    D --> O
    D --> P
```

### Key Architecture Principles

1. **Privacy-First**: All data is scoped to authenticated user's `user_id`
2. **AI Independence**: App never talks directly to AI services — all goes through backend
3. **Batch-Level Tracking**: Each received batch is a separate inventory item
4. **GS1 Compliance**: Full support for GS1 barcode parsing (GTIN, lot, expiry)

---

## ✨ Key Features

### 🔐 Accounts & Authentication
- **Secure Registration/Login** with JWT bearer tokens
- **Argon2 Password Hashing** via `passlib`
- **Token Storage** with `flutter_secure_storage` (60-minute expiry)
- **User-Isolated Data**: Each user sees only their own inventory

### 📦 Relational Medicine Catalog
- **Rich Data Model**: Medicines linked to manufacturers and categories
- **Smart Creation**: Auto-resolves manufacturer/category names
- **Many-to-Many Categories**: Medicines can belong to multiple categories
- **Eager Loading**: All relationships preloaded for performance

### 📊 Batch-Level Inventory
- **Serialized Batches**: Each batch has unique lot number and expiry
- **Dispense/Restock**: Decrement/increment with automatic cleanup
- **Zero-Quantity Auto-Delete**: Batches removed when stock hits zero
- **Medicine Cleanup**: If last batch is removed, medicine is also deleted

### 📱 Barcode Scanning
- **GS1 Barcode Support**: Parses GTIN (01), lot (10), expiry (17)
- **Auto-Create**: Creates placeholder medicine if GTIN is new
- **Seamless Integration**: Scan → parse → receive stock in one call

### 🤖 OCR Label Capture
- **EasyOCR Integration**: Extracts text from medicine packaging
- **Intelligent Parsing**: Finds expiry dates, prices, lot numbers
- **LLM Enhancement**: Groq fills in missing fields (name, manufacturer, strength)
- **Batch Creation**: Creates medicine + first inventory batch

### 🎤 Voice Entry
- **Whisper Transcription**: Local `tiny.en` model for speech-to-text
- **Structured Extraction**: Groq extracts medicine details from natural speech
- **One-Shot Creation**: Creates medicine and batch from voice command
- **Flexible Input**: "Received 20 units of Paracetamol 500mg from Cipla..."

### 💬 AI Chatbot
- **Natural Language Queries**: Ask inventory questions in plain English
- **Function Calling**: Groq decides when to call stock/expiry functions
- **Real-Time Answers**: "How many Paracetamol do we have?" → "45 units"
- **User-Scoped**: Queries only see current user's inventory

### 🔄 Dispense / Restock Workflow
- **Atomic Operations**: Ensures stock consistency
- **Sufficiency Checks**: Rejects dispense if stock insufficient
- **Automatic Cleanup**: Removes empty batches and medicines
- **Audit Trail**: Complete transaction history (optional)

---

## 📊 Data Model

```mermaid
erDiagram
    User ||--o{ Medicine : "owns"
    User {
        int id PK
        string username
        string hashed_password
        boolean is_active
    }
    
    Medicine ||--o{ InventoryItem : "has"
    Medicine {
        int id PK
        string barcode
        string name
        string strength
        decimal price
        date expiry_date
        int user_id FK
        int manufacturer_id FK
        boolean requires_prescription
        text storage_instructions
        text side_effects
    }
    
    Manufacturer ||--o{ Medicine : "produces"
    Manufacturer {
        int id PK
        string name
        string contact_email
        string phone
        string address
        string country
        string website
        boolean is_verified
    }
    
    Medicine }o--o{ Category : "belongs to"
    Category {
        int id PK
        string name
        string description
    }
    
    InventoryItem {
        int id PK
        int medicine_id FK
        string lot_number
        date expiry_date
        int quantity
    }
```

### Model Details

| Model | Key Fields | Relationships |
|-------|-----------|---------------|
| **User** | `username` (unique), `hashed_password`, `is_active` | Owns medicines |
| **Medicine** | `barcode`, `name`, `strength`, `price`, `expiry_date` | Belongs to User & Manufacturer; has Categories & InventoryItems |
| **Manufacturer** | `name` (unique), `contact_email`, `phone`, `address`, `country` | Produces Medicines |
| **Category** | `name` (unique), `description` | Classifies Medicines |
| **InventoryItem** | `lot_number`, `expiry_date`, `quantity` | Belongs to Medicine |

**Important**: Medicine `expiry_date`/`price` are for backward compatibility. Source of truth for "what's in stock" is `InventoryItem` table.

---

## 📡 Backend API Reference

### Authentication Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | Health check |
| `POST` | `/register` | Create user account |
| `POST` | `/token` | Login (OAuth2 password flow) → JWT |

### Medicine Endpoints (All require JWT)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/medicines/` | List user's medicines (with manufacturer/categories/inventory) |
| `GET` | `/medicines/barcode/{barcode}` | Lookup medicine by barcode |
| `PUT` | `/medicines/{medicine_id}` | Update medicine fields |
| `DELETE` | `/medicines/{medicine_id}` | Delete medicine + all inventory |
| `POST` | `/medicines/smart-create` | Create medicine + batch (auto-resolves manufacturer/category) |

### Inventory Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/inventory/receive` | Add new batch to existing medicine |
| `POST` | `/inventory/receive-gs1` | Parse GS1 scan and receive stock |
| `POST` | `/inventory/dispense` | Decrease batch quantity (auto-delete at zero) |
| `POST` | `/inventory/restock` | Increase batch quantity |

### AI Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/ocr/extract-text` | OCR on image → raw text + parsed fields |
| `POST` | `/voice/process-audio` | Transcribe audio → create medicine + batch |
| `POST` | `/chatbot/query` | Natural language inventory questions |
| `POST` | `/chatbot/parse-medicine-text` | LLM-parses OCR text → structured medicine |

### Interactive Docs
- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

### Example: Smart Create Request

```json
POST /medicines/smart-create
Authorization: Bearer <jwt-token>

{
  "name": "Paracetamol",
  "strength": "500mg",
  "barcode": "8901234567890",
  "price": 45.50,
  "manufacturer": "Cipla",
  "categories": ["Analgesics", "Fever"],
  "requires_prescription": false,
  "storage_instructions": "Store below 30°C",
  "side_effects": "Nausea, rash",
  "batch": {
    "lot_number": "BATCH001",
    "quantity": 100,
    "expiry_date": "2025-12-31"
  }
}
```

### Example: Chatbot Query

```json
POST /chatbot/query
Authorization: Bearer <jwt-token>

{
  "message": "How many Paracetamol do we have in stock?"
}
```

**Response**:
```json
{
  "reply": "You have 45 units of Paracetamol 500mg in stock across 3 batches.",
  "tool_calls_used": ["get_stock_quantity"]
}
```

---

## 📱 Flutter App

### Screens Overview

| Screen | File | Purpose |
|--------|------|---------|
| **Login** | `login_screen.dart` | Authenticate with `/token`, store JWT securely |
| **Registration** | `registration_screen.dart` | Create new account via `/register` |
| **Inventory List** | `inventory_list_screen.dart` | Home screen — browse medicines and stock levels |
| **Medicine Detail** | `medicine_detail_screen.dart` | View batches, dispense/restock |
| **Create Medicine** | `create_medicine_screen.dart` | Manual entry of medicine + batch |
| **Edit Medicine** | `edit_medicine_screen.dart` | Update medicine fields |
| **Scanner** | `scanner_screen.dart` | Barcode/GS1 scanning with `mobile_scanner` |
| **OCR Capture** | `ocr_screen.dart` | Photo capture → OCR → LLM → confirm |
| **Voice Entry** | `voice_screen.dart` | Record audio → Whisper → Groq → create |
| **Chatbot** | `chat_bot_screen.dart` | AI chatbot with `flutter_chat_ui` |

### State Management

```dart
// AuthService - Manages authentication state
class AuthService extends ChangeNotifier {
  String? _token;
  bool get isAuthenticated => _token != null;
  
  Future<void> login(String username, String password) async {
    // Call /token, store in flutter_secure_storage
  }
  
  Future<void> logout() async {
    // Clear token and notify listeners
  }
}

// ApiService - HTTP client with JWT interceptor
class ApiService {
  final AuthService _authService;
  
  Future<Response> _request(String method, String path, {body}) async {
    final token = await _authService.token;
    // Add Authorization: Bearer <token> header
  }
}
```

### Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **Android** | ✅ Full support | Camera, microphone permissions |
| **iOS** | ✅ Full support | Camera, microphone permissions |
| **Web** | ✅ Full support | Camera access via getUserMedia |
| **Windows** | ✅ Full support | Desktop camera support |
| **macOS** | ✅ Full support | Desktop camera support |
| **Linux** | ✅ Full support | Desktop camera support |

---

## 🤖 AI Features

### 1. OCR Pipeline

```
Photo → EasyOCR → Raw Text → Regex Parsing → LLM Enhancement → Structured Medicine
```

**Regex Helpers**:
- `find_and_parse_date()`: Extracts expiry dates
- `find_and_parse_price()`: Finds MRP/price
- `find_lot_number()`: Identifies batch numbers

**LLM Enhancement** (Groq):
```python
# Takes raw text, returns structured medicine
{
  "name": "Paracetamol",
  "strength": "500mg",
  "manufacturer": "Cipla",
  "category": "Analgesics",
  "requires_prescription": false,
  "storage_instructions": "...",
  "side_effects": "..."
}
```

### 2. Voice Pipeline

```
Audio Recording → Whisper tiny.en → Transcript → Groq Extraction → Medicine + Batch
```

**Example Input**:
> "Received 20 units of Paracetamol 500mg from Cipla, batch AB123, expiry March 2026"

**Extracted Output**:
```json
{
  "medicine": {
    "name": "Paracetamol",
    "strength": "500mg",
    "manufacturer": "Cipla",
    "price": 45.50
  },
  "batch": {
    "lot_number": "AB123",
    "quantity": 20,
    "expiry_date": "2026-03-01"
  }
}
```

### 3. Chatbot Pipeline

```
User Query → Groq (with tools) → Stock/Expiry Queries → Natural Language Reply
```

**Available Tools**:
- `get_stock_quantity(medicine_name)`: Returns total stock
- `find_expiring_medicines(days)`: Returns list of expiring batches

**Example Flow**:
1. User: "What medicines are expiring soon?"
2. Groq decides: Call `find_expiring_medicines(days=30)`
3. Function returns: `[{"name":"Paracetamol","batch":"B001","expiry":"2025-12-15"}]`
4. Groq replies: "Two medicines are expiring in the next 30 days: Paracetamol (batch B001) on December 15..."

---

## 🛠️ Tech Stack

### Backend

| Component | Technology | Version |
|-----------|------------|---------|
| **Web Framework** | FastAPI | 0.104+ |
| **ORM** | SQLAlchemy | 2.0+ |
| **Database** | PostgreSQL | 15+ |
| **Auth** | python-jose (JWT) + passlib[argon2] | - |
| **OCR** | EasyOCR | 1.7+ |
| **Speech-to-Text** | OpenAI Whisper (tiny.en) | - |
| **LLM** | Groq (llama-3.1-8b-instant) | - |
| **Date Parsing** | python-dateutil | - |

### Flutter App

| Component | Technology | Version |
|-----------|------------|---------|
| **Framework** | Flutter | 3.8+ |
| **State Management** | provider | 6.0+ |
| **Barcode Scanner** | mobile_scanner | 4.0+ |
| **Camera** | image_picker | 1.0+ |
| **Audio Recording** | flutter_sound | 9.0+ |
| **Permissions** | permission_handler | 11.0+ |
| **Chat UI** | flutter_chat_ui | 1.6+ |
| **Secure Storage** | flutter_secure_storage | 9.0+ |
| **App Icons** | flutter_launcher_icons | - |

---

## 📁 Project Structure

```
PharmaPal/
├── main.py                          # FastAPI app - all routes
├── models.py                        # SQLAlchemy models
├── schemas.py                       # Pydantic schemas
├── auth.py                          # JWT + password hashing
├── database.py                      # DB engine/session
├── test.py                          # Scratch/test script
├── .env                             # Environment variables
├── pharmaapp/                       # Flutter application
│   ├── pubspec.yaml                 # Flutter dependencies
│   ├── android/                     # Android build config
│   ├── ios/                         # iOS build config
│   ├── web/                         # Web build config
│   └── lib/
│       ├── main.dart                # App entry point
│       ├── api_service.dart         # HTTP client
│       ├── auth_service.dart        # Auth state management
│       ├── medicine.dart            # Data models
│       ├── login_screen.dart
│       ├── registration_screen.dart
│       ├── inventory_list_screen.dart
│       ├── medicine_detail_screen.dart
│       ├── create_medicine_screen.dart
│       ├── edit_medicine_screen.dart
│       ├── scanner_screen.dart
│       ├── ocr_screen.dart
│       ├── voice_screen.dart
│       ├── chat_bot_screen.dart
│       └── app_background.dart       # Shared UI components
└── README.md                         # This file
```

---

## 🚀 Getting Started

### Prerequisites

- Python 3.9+ (3.12 recommended)
- PostgreSQL 15+ (or Neon serverless)
- Flutter SDK 3.8+
- Enough disk/RAM for EasyOCR + Whisper models
- Groq API key (free tier available)

### Backend Setup

1. **Clone the Repository**
```bash
git clone https://github.com/yourusername/pharmapal.git
cd pharmapal
```

2. **Create Virtual Environment**
```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
```

3. **Install Dependencies**
```bash
pip install fastapi uvicorn sqlalchemy psycopg2-binary python-dotenv \
    python-jose[cryptography] passlib[argon2] python-multipart \
    easyocr openai-whisper openai transformers torch python-dateutil \
    pydantic-settings
```

4. **Configure Environment**
```bash
# Create .env file
cat > .env << EOF
DATABASE_URL=postgresql://user:password@localhost:5432/pharmapal_db
GROQ_API_KEY=gsk_xxxxx  # Get from https://console.groq.com
SECRET_KEY=your-super-secret-jwt-key-min-32-chars
EOF
```

5. **Create Database**
```bash
createdb pharmapal_db  # PostgreSQL
```

6. **Run the Backend**
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

7. **Verify**
```bash
curl http://localhost:8000/
# {"status": "ok", "message": "PharmaPal API is running"}
```

### Flutter App Setup

1. **Navigate to Flutter App**
```bash
cd pharmaapp
```

2. **Update Backend URL** (in `lib/api_service.dart` and `lib/auth_service.dart`)
```dart
// Change these to point to your backend
static const String _baseUrl = 'http://10.182.230.122:8000';
```

3. **Get Dependencies**
```bash
flutter pub get
```

4. **Run the App**
```bash
flutter run
```

5. **Generate Icons** (optional)
```bash
flutter pub run flutter_launcher_icons:main
```

### First-Time Setup

1. **Register** a new user account
2. **Login** with your credentials
3. **Start managing** inventory:
   - Scan barcodes with camera
   - Take photos of packaging for OCR
   - Record voice notes for quick entry
   - Ask chatbot questions about your inventory

---

## 🔒 Security Notes

### Critical Security Considerations

| Issue | Current State | Recommended Action |
|-------|---------------|-------------------|
| **Secret Key** | Hardcoded fallback in `auth.py` | Always use environment variable |
| **CORS** | `allow_origins=["*"]` | Restrict to specific origins |
| **Base URL** | Hardcoded LAN IP in Flutter | Centralize in build config |
| **Registration** | No rate limiting | Add CAPTCHA + rate limits |
| **.env File** | Contains real-looking values | Replace & add to .gitignore |

### Environment Variables

```bash
# Required
DATABASE_URL=postgresql://user:password@host:5432/dbname
GROQ_API_KEY=gsk_xxxxxxxxxx
SECRET_KEY=your-secure-secret-key-32-chars-min

# Optional
JWT_ALGORITHM=HS256
JWT_EXPIRE_MINUTES=60
```

### Production Readiness Checklist

- [ ] Rotate SECRET_KEY
- [ ] Update GROQ_API_KEY
- [ ] Change DATABASE_URL
- [ ] Restrict CORS origins
- [ ] Add HTTPS (SSL/TLS)
- [ ] Implement rate limiting
- [ ] Add user roles/permissions
- [ ] Set up database backups
- [ ] Configure logging/monitoring
- [ ] Add health checks
- [ ] Implement audit trails

---

## ☁️ Deployment

### Docker Deployment

```dockerfile
# Dockerfile for backend
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV PYTHONUNBUFFERED=1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  backend:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - GROQ_API_KEY=${GROQ_API_KEY}
      - SECRET_KEY=${SECRET_KEY}
    depends_on:
      - db
    volumes:
      - ./models:/app/models

  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=pharmapal_db
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### Deploy to Render

1. **Create `requirements.txt`**:
```txt
fastapi==0.104.1
uvicorn==0.24.0
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
python-dotenv==1.0.0
python-jose[cryptography]==3.3.0
passlib[argon2]==1.7.4
python-multipart==0.0.6
easyocr==1.7.1
openai-whisper==20231117
openai==1.6.1
transformers==4.35.0
torch==2.1.0
python-dateutil==2.8.2
pydantic-settings==2.1.0
```

2. **Create `start.sh`**:
```bash
#!/bin/bash
uvicorn main:app --host 0.0.0.0 --port $PORT
chmod +x start.sh
```

3. **Deploy**:
   - Connect GitHub repo to Render
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `./start.sh`
   - Environment Variables: Add DATABASE_URL, GROQ_API_KEY, SECRET_KEY

---

## 🤝 Contributing

We welcome contributions!

### Development Workflow

```bash
# Fork and clone
git clone https://github.com/yourusername/pharmapal.git
cd pharmapal

# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements-dev.txt

# Make changes
# Run tests
pytest tests/

# Format code
black .
isort .

# Commit and push
git add .
git commit -m "Add: feature description"
git push origin feature/your-feature

# Create Pull Request
```

### Code Standards

- **Python**: PEP 8, type hints, docstrings
- **Dart**: Flutter style guide, `dart format`
- **Commits**: Conventional Commits

---

##  Acknowledgments

### Open Source Projects
- [FastAPI](https://fastapi.tiangolo.com) - Modern Python web framework
- [Flutter](https://flutter.dev) - Cross-platform UI framework
- [EasyOCR](https://github.com/JaidedAI/EasyOCR) - OCR library
- [Whisper](https://github.com/openai/whisper) - Speech-to-text
- [Groq](https://groq.com) - Fast LLM inference

### AI Models
- **Whisper tiny.en**: Lightweight speech transcription
- **Llama 3.1 8B**: Structured extraction and chatbot via Groq
- **EasyOCR**: Multi-language text extraction

---


</div>
