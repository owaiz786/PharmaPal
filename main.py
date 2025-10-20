# main.py
from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.orm import Session
from typing import List
import re
from datetime import datetime, date, timedelta
from dateutil.parser import parse as parse_date
import models, schemas
from database import SessionLocal, engine
from fastapi.responses import JSONResponse
import easyocr
import os
import json
import whisper
from transformers import pipeline
import torch
from sqlalchemy.exc import IntegrityError
from openai import OpenAI
from fastapi.security import OAuth2PasswordRequestForm
import auth

print(f"--- Loaded groq API Key: {os.getenv('GROQ_API_KEY')} ---")

# Initialize the client to point to Groq's API endpoint
client = OpenAI(
    api_key=os.getenv("GROQ_API_KEY"),
    base_url="https://api.groq.com/openai/v1"
)

# --- INITIALIZATIONS (Done once on startup) ---

models.Base.metadata.create_all(bind=engine)

# Initialize EasyOCR reader
print("Loading EasyOCR model...")
reader = easyocr.Reader(['en']) 

# Initialize Whisper model for speech-to-text
print("Loading Whisper model...")
whisper_model = whisper.load_model("tiny.en")

app = FastAPI(
    title="PharmPal API",
    description="API for Pharmaceutical Inventory Management",
    version="1.0.0",
)

# --- HELPER & DATABASE FUNCTIONS ---

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def verify_medicine_ownership(medicine_id: int, user_id: int, db: Session):
    """Helper function to verify medicine ownership"""
    medicine = db.query(models.Medicine).filter(
        models.Medicine.id == medicine_id,
        models.Medicine.user_id == user_id
    ).first()
    if not medicine:
        raise HTTPException(status_code=404, detail="Medicine not found or you don't have permission to access it")
    return medicine

def verify_inventory_ownership(item_id: int, user_id: int, db: Session):
    """Helper function to verify inventory item ownership through medicine"""
    item = db.query(models.InventoryItem).filter(models.InventoryItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Inventory item not found")
    
    medicine = db.query(models.Medicine).filter(
        models.Medicine.id == item.medicine_id,
        models.Medicine.user_id == user_id
    ).first()
    if not medicine:
        raise HTTPException(status_code=404, detail="You don't have permission to access this inventory item")
    return item

def _smart_create_db_entry(data: schemas.SmartCreateRequest, db: Session, user_id: int):
    """
    Safely creates a new medicine and its first inventory item.
    Handles both voice input (no barcode) and scan input (with barcode).
    Includes debugging prints and robust error handling.
    """
    # --- STEP 1: DEBUGGING PRINT ---
    print("\n--- ATTEMPTING TO SAVE TO DATABASE ---")
    print(f"Data received for validation: {data.dict()}")
    print(f"User ID: {user_id}")
    print("------------------------------------\n")
    
    try:
        # --- STEP 2: HANDLE BARCODE LOGIC ---
        if data.barcode:
            existing_medicine = db.query(models.Medicine).filter(
                models.Medicine.barcode == data.barcode,
                models.Medicine.user_id == user_id  # Only check user's own medicines
            ).first()
            if existing_medicine:
                print(f"Found existing medicine '{existing_medicine.name}' via barcode. Adding new batch.")
                new_inventory_item = models.InventoryItem(
                    medicine_id=existing_medicine.id,
                    lot_number=data.lot_number,
                    quantity=data.quantity,
                    expiry_date=data.expiry_date
                )
                db.add(new_inventory_item)
                db.commit()
                db.refresh(existing_medicine)
                return existing_medicine

        # --- STEP 3: CREATE NEW MEDICINE ---
        print(f"Creating new medicine catalog entry for '{data.name}'.")
        new_medicine = models.Medicine(
            barcode=data.barcode,
            name=data.name,
            user_id=user_id,
            manufacturer=data.manufacturer,
            strength=data.strength,
            price=data.price,
            expiry_date=data.expiry_date
        )
        db.add(new_medicine)
        db.commit()
        db.refresh(new_medicine)

        # --- STEP 4: CREATE THE INVENTORY BATCH ---
        print(f"Creating new inventory batch for '{data.name}' with lot '{data.lot_number}'.")
        new_inventory_item = models.InventoryItem(
            medicine_id=new_medicine.id,
            lot_number=data.lot_number,
            quantity=data.quantity,
            expiry_date=data.expiry_date
        )
        db.add(new_inventory_item)
        db.commit()
        db.refresh(new_medicine)
        
        print("--- DATABASE SAVE SUCCESSFUL ---")
        return new_medicine

    # --- STEP 5: ROBUST ERROR HANDLING ---
    except IntegrityError as e:
        print(f"!!! DATABASE INTEGRITY ERROR: {e} !!!")
        db.rollback()
        raise HTTPException(status_code=409, detail=f"A medicine with this barcode ('{data.barcode}') already exists. The operation was cancelled.")
    except Exception as e:
        print(f"!!! UNEXPECTED DATABASE ERROR: {e} !!!")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred while saving to the database: {e}")

def find_and_parse_date(text_block: str):
    date_pattern = r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2}|\d{1,2}[ -](?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[ -]\d{2,4})'
    match = re.search(date_pattern, text_block, re.IGNORECASE)
    if match:
        try:
            return parse_date(match.group(0)).date()
        except (ValueError, OverflowError):
            return None
    return None

def find_and_parse_price(text_block: str):
    price_pattern = r'(?:MRP|Rs\.?|\$)\s*[:\- ]?\s*(\d+\.?\d*)'
    match = re.search(price_pattern, text_block, re.IGNORECASE)
    if match:
        try:
            return float(match.group(1))
        except ValueError:
            return None
    return None

def find_lot_number(text_block: str):
    lot_pattern = r'(?:Batch|Lot|B\.?No)\.?\s*:?\s*([\w\-]+)'
    match = re.search(lot_pattern, text_block, re.IGNORECASE)
    if match:
        return match.group(1)
    return None

def parse_gs1_string(data: str) -> dict:
    parsed_data = {}
    gtin_match = re.search(r'\(01\)(\d+)', data)
    if gtin_match: parsed_data['gtin'] = gtin_match.group(1)
    lot_match = re.search(r'\(10\)([\w-]+)', data)
    if lot_match: parsed_data['lot_number'] = lot_match.group(1)
    expiry_match = re.search(r'\(17\)(\d{6})', data)
    if expiry_match:
        try:
            parsed_data['expiry_date'] = datetime.strptime(expiry_match.group(1), '%y%m%d').date()
        except ValueError: pass
    return parsed_data

# --- API ENDPOINTS ---

@app.post("/register", response_model=schemas.User)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    """Register a new user"""
    db_user = auth.get_user_by_username(db, username=user.username)
    if db_user:
        raise HTTPException(status_code=400, detail="Username already registered")
    
    hashed_password = auth.get_password_hash(user.password)
    new_user = models.User(username=user.username, hashed_password=hashed_password)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

@app.post("/token", response_model=schemas.Token)
async def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(), 
    db: Session = Depends(get_db)
):
    """Login to get access token"""
    user = auth.get_user_by_username(db, username=form_data.username)
    if not user or not auth.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=auth.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/medicines/", response_model=List[schemas.Medicine])
def get_all_medicines(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """Get all medicines for the current user"""
    medicines = db.query(models.Medicine).filter(
        models.Medicine.user_id == current_user.id
    ).all()
    return medicines
@app.get("/medicines/{medicine_id}", response_model=schemas.Medicine)
def read_medicine(
    medicine_id: int, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """Get a specific medicine by ID (only if owned by current user)"""
    db_medicine = verify_medicine_ownership(medicine_id, current_user.id, db)
    return db_medicine

@app.get("/medicines/barcode/{barcode}", response_model=schemas.Medicine)
def read_medicine_by_barcode(
    barcode: str, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """Get a medicine by barcode (only if owned by current user)"""
    db_medicine = db.query(models.Medicine).filter(
        models.Medicine.barcode == barcode,
        models.Medicine.user_id == current_user.id
    ).first()
    if db_medicine is None:
        raise HTTPException(status_code=404, detail="Medicine with this barcode not found")
    return db_medicine

@app.put("/medicines/{medicine_id}", response_model=schemas.Medicine)
def update_medicine_details(
    medicine_id: int, 
    medicine_update: schemas.MedicineCreate, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """Update medicine details (only if owned by current user)"""
    db_medicine = verify_medicine_ownership(medicine_id, current_user.id, db)
    
    update_data = medicine_update.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_medicine, key, value)
    db.commit()
    db.refresh(db_medicine)
    return db_medicine

@app.delete("/medicines/{medicine_id}", status_code=200)
def delete_medicine(
    medicine_id: int, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """Delete a medicine and all its inventory items (only if owned by current user)"""
    db_medicine = verify_medicine_ownership(medicine_id, current_user.id, db)
    
    db.query(models.InventoryItem).filter(models.InventoryItem.medicine_id == medicine_id).delete()
    db.delete(db_medicine)
    db.commit()
    return {"message": "Medicine deleted successfully."}

@app.post("/medicines/smart-create", response_model=schemas.Medicine)
def smart_create_medicine_and_inventory(
    request: schemas.SmartCreateRequest, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """Smart create medicine with inventory (secured to current user)"""
    return _smart_create_db_entry(request, db, user_id=current_user.id)

@app.post("/inventory/receive", response_model=schemas.InventoryItem, status_code=201)
def receive_inventory_item(
    item: schemas.InventoryItemCreate, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """Receive new inventory item (only for medicines owned by current user)"""
    db_medicine = verify_medicine_ownership(item.medicine_id, current_user.id, db)
    
    db_item = models.InventoryItem(**item.dict())
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

@app.post("/inventory/receive-gs1", response_model=schemas.InventoryItem)
def receive_inventory_from_gs1_scan(
    scan_data: schemas.GS1ScanRequest, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """Receive inventory from GS1 barcode scan (secured to current user)"""
    parsed_data = parse_gs1_string(scan_data.gs1_data)
    if not all(k in parsed_data for k in ['gtin', 'lot_number', 'expiry_date']):
        raise HTTPException(status_code=400, detail="Incomplete GS1 data.")
    
    gtin = parsed_data['gtin']
    medicine = db.query(models.Medicine).filter(
        models.Medicine.barcode == gtin,
        models.Medicine.user_id == current_user.id
    ).first()
    
    if not medicine:
        medicine = models.Medicine(
            barcode=gtin, 
            name=f"New Medicine - GTIN {gtin}", 
            manufacturer="Unknown", 
            strength="N/A", 
            price=0.0, 
            expiry_date=parsed_data['expiry_date'],
            user_id=current_user.id
        )
        db.add(medicine)
        db.commit()
        db.refresh(medicine)
    
    new_item = models.InventoryItem(
        medicine_id=medicine.id, 
        lot_number=parsed_data['lot_number'], 
        expiry_date=parsed_data['expiry_date'], 
        quantity=scan_data.quantity
    )
    db.add(new_item)
    db.commit()
    db.refresh(new_item)
    return new_item

@app.post("/inventory/dispense")
def dispense_inventory_item(
    dispense_request: schemas.DispenseRequest, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """Dispense inventory item (only if owned by current user)"""
    db_item = verify_inventory_ownership(dispense_request.item_id, current_user.id, db)
    
    if db_item.quantity < dispense_request.quantity:
        raise HTTPException(status_code=400, detail="Insufficient stock.")
    
    db_item.quantity -= dispense_request.quantity
    if db_item.quantity == 0:
        medicine_id_to_check = db_item.medicine_id
        db.delete(db_item)
        db.commit()
        remaining_items = db.query(models.InventoryItem).filter(
            models.InventoryItem.medicine_id == medicine_id_to_check
        ).count()
        if remaining_items == 0:
            medicine_to_delete = db.query(models.Medicine).filter(
                models.Medicine.id == medicine_id_to_check,
                models.Medicine.user_id == current_user.id
            ).first()
            if medicine_to_delete:
                db.delete(medicine_to_delete)
                db.commit()
            return JSONResponse(status_code=200, content={"message": "Item dispensed and catalog entry removed."})
        return JSONResponse(status_code=200, content={"message": "Item dispensed and batch removed."})
    else:
        db.commit()
        db.refresh(db_item)
        return db_item

@app.post("/inventory/restock", response_model=schemas.InventoryItem)
def restock_inventory_item(
    restock_request: schemas.RestockRequest, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """Restock inventory item (only if owned by current user)"""
    db_item = verify_inventory_ownership(restock_request.item_id, current_user.id, db)
    
    db_item.quantity += restock_request.quantity
    db.commit()
    db.refresh(db_item)
    return db_item

@app.post("/ocr/extract-text")
def extract_text_from_image(
    file: UploadFile = File(...),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """Extract text from medicine package image using OCR (authenticated users only)"""
    image_bytes = file.file.read()
    result = reader.readtext(image_bytes)
    full_text = " ".join([text for bbox, text, conf in result])
    if not full_text:
        raise HTTPException(status_code=400, detail="No text detected.")
    found_date = find_and_parse_date(full_text)
    found_price = find_and_parse_price(full_text)
    found_lot = find_lot_number(full_text)
    return {
        "found_text": full_text, 
        "parsed_date": found_date.isoformat() if found_date else None, 
        "parsed_price": found_price, 
        "parsed_lot": found_lot
    }

@app.post("/voice/process-audio", response_model=schemas.Medicine)
def process_voice_audio(
    db: Session = Depends(get_db), 
    file: UploadFile = File(...), 
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Receives an audio file, transcribes it with Whisper, uses the GROQ API
    to parse the text, and creates a new medicine and inventory item.
    """
    # --- STEP 1: Transcribe audio to text with Whisper ---
    temp_audio_path = f"./temp_{file.filename}"
    with open(temp_audio_path, "wb") as buffer:
        buffer.write(file.file.read())
    try:
        result = whisper_model.transcribe(temp_audio_path)
        transcribed_text = result["text"]
        print(f"Whisper transcribed: '{transcribed_text}'")
    finally:
        os.remove(temp_audio_path)

    if not transcribed_text or not transcribed_text.strip():
        raise HTTPException(status_code=400, detail="Could not understand the audio or speech was empty.")
        
    # --- STEP 2: Use Groq API to parse the transcribed text ---
    parsing_prompt = f"""
    You are an expert AI assistant for pharmaceutical inventory. Your task is to extract structured data from a user's voice transcription.
    You must parse this text to extract the following fields:
    - name (string, required)
    - manufacturer (string, optional, default to "Unknown" if not mentioned)
    - strength (string, optional, default to "N/A" if not mentioned)
    - price (float, required, if not mentioned use 0.0)
    - lot_number (string, required, if not mentioned generate one like "LOT-VOICE-[timestamp]")
    - quantity (integer, required)
    - expiry_date (string, in "YYYY-MM-DD" format, required)
    - barcode (string, optional, can be null)

    IMPORTANT RULES:
    - DO NOT use null for price or lot_number
    - If price is not mentioned, use 0.0
    - If lot_number is not mentioned, generate a unique one with format "LOT-VOICE-YYYYMMDD"
    - If manufacturer is not mentioned, use "Unknown"
    - If strength is not mentioned, use "N/A"
    
    You MUST respond ONLY with a single, valid JSON object containing these fields. Do not add any explanation or conversational text.

    User's transcribed text: "{transcribed_text}"
    """
    
    try:
        response = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[{"role": "user", "content": parsing_prompt}],
            temperature=0.0,
            response_format={"type": "json_object"},
        )
        
        parsed_json_str = response.choices[0].message.content
        print(f"Groq parsed JSON: {parsed_json_str}")
        parsed_data = json.loads(parsed_json_str)

        # --- STEP 2.5: Validate and fix null values ---
        if parsed_data.get("price") is None:
            parsed_data["price"] = 0.0
            print("Warning: price was null, defaulting to 0.0")
        
        if parsed_data.get("lot_number") is None or not parsed_data.get("lot_number"):
            parsed_data["lot_number"] = f"LOT-VOICE-{datetime.now().strftime('%Y%m%d%H%M%S')}"
            print(f"Warning: lot_number was null, generated: {parsed_data['lot_number']}")
        
        if parsed_data.get("manufacturer") is None:
            parsed_data["manufacturer"] = "Unknown"
        
        if parsed_data.get("strength") is None:
            parsed_data["strength"] = "N/A"

        # Convert string values to proper types if needed
        try:
            parsed_data["price"] = float(parsed_data["price"])
        except (ValueError, TypeError):
            parsed_data["price"] = 0.0
        
        try:
            parsed_data["quantity"] = int(parsed_data["quantity"])
        except (ValueError, TypeError):
            raise HTTPException(status_code=400, detail="Quantity must be a valid number")

        print(f"Cleaned data: {parsed_data}")
        
        smart_request = schemas.SmartCreateRequest(**parsed_data)

        # --- STEP 3: Call our reusable helper to save to the database ---
        return _smart_create_db_entry(smart_request, db, user_id=current_user.id)

    except HTTPException:
        raise
    except Exception as e:
        print(f"Error processing voice utterance with Groq: {e}")
        error_detail = str(e)
        if 'parsed_json_str' in locals():
            error_detail += f" | Raw Model Output: {parsed_json_str}"
        raise HTTPException(status_code=400, detail=f"Could not parse the voice input. Please be more specific. Details: {error_detail}")
@app.post("/chatbot/query")
def chatbot_query(
    request: dict, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """Handles chatbot queries using the Groq API with function calling (user-specific data only)"""
    user_message = request.get("message")
    if not user_message:
        raise HTTPException(status_code=400, detail="Message is required.")
    
    if not client.api_key:
        print("!!! GROQ API KEY NOT LOADED. CHECK .ENV FILE. !!!")
        raise HTTPException(status_code=500, detail="API key not configured.")
    
    messages = [{"role": "user", "content": user_message}]
    
    # Define available tool functions - scoped to current user
    def get_stock_quantity_wrapper(medicine_name: str, db: Session):
        medicine = db.query(models.Medicine).filter(
            models.Medicine.name.ilike(f"%{medicine_name}%"),
            models.Medicine.user_id == current_user.id
        ).first()
        if not medicine: 
            return f"Medicine '{medicine_name}' not found in your inventory."
        total_quantity = sum(item.quantity for item in medicine.inventory_items)
        return json.dumps({"medicine_name": medicine.name, "total_quantity": total_quantity})
    
    def find_expiring_medicines_wrapper(days_limit: int, db: Session):
        expiry_threshold = date.today() + timedelta(days=days_limit)
        expiring_items = db.query(models.InventoryItem).join(
            models.Medicine
        ).filter(
            models.InventoryItem.expiry_date <= expiry_threshold,
            models.Medicine.user_id == current_user.id
        ).all()
        
        if not expiring_items: 
            return "No medicines are expiring soon in your inventory."
        results = [
            {
                "medicine_name": item.medicine.name, 
                "lot_number": item.lot_number, 
                "expiry_date": item.expiry_date.isoformat()
            } 
            for item in expiring_items
        ]
        return json.dumps(results)
    
    available_functions = {
        "get_stock_quantity": get_stock_quantity_wrapper,
        "find_expiring_medicines": find_expiring_medicines_wrapper,
    }
    
    tools = [
        {
            "type": "function",
            "function": {
                "name": "get_stock_quantity",
                "description": "Get the total stock quantity for a specific medicine in the user's inventory.",
                "parameters": {
                    "type": "object",
                    "properties": { 
                        "medicine_name": {
                            "type": "string", 
                            "description": "The name of the medicine, e.g., 'Paracetamol'"
                        }
                    },
                    "required": ["medicine_name"],
                },
            },
        },
        {
            "type": "function",
            "function": {
                "name": "find_expiring_medicines",
                "description": "Find all medicine batches in the user's inventory that are expiring within a given number of days.",
                "parameters": {
                    "type": "object",
                    "properties": { 
                        "days_limit": {
                            "type": "integer", 
                            "description": "Number of days from today to check for expiry, e.g., 30"
                        }
                    },
                    "required": ["days_limit"],
                },
            },
        }
    ]

    try:
        # --- Step 1: Send initial message to Groq ---
        response = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=messages,
            tools=tools,
            tool_choice="auto",
        )
        
        response_message = response.choices[0].message
        tool_calls = getattr(response_message, "tool_calls", None)
        final_response = None

        # --- Step 2: Handle function calling logic ---
        if tool_calls:
            for tool_call in tool_calls:
                function_name = tool_call.function.name
                function_args = json.loads(tool_call.function.arguments)

                print("\n--- AI TOOL CALL DECISION ---")
                print(f"Tool to call: {function_name}")
                print(f"Arguments: {function_args}")
                print("-----------------------------\n")
                
                if function_name not in available_functions:
                    raise HTTPException(status_code=400, detail=f"Unknown function: {function_name}")
                
                function_to_call = available_functions[function_name]
                function_args["db"] = db
                
                function_response = function_to_call(**function_args)
                
                messages.append({
                    "tool_call_id": tool_call.id,
                    "role": "tool",
                    "name": function_name,
                    "content": str(function_response),
                })
            
            # --- Step 3: Ask the model to summarize the function output ---
            second_response = client.chat.completions.create(
                model="llama-3.1-8b-instant",
                messages=messages,
            )
            final_response = second_response.choices[0].message.content
        else:
            final_response = response_message.content

        return {"response": final_response}

    except Exception as e:
        print(f"Error communicating with Groq or database: {e}")
        raise HTTPException(status_code=500, detail=f"Chatbot internal error: {str(e)}")
    
@app.post("/chatbot/parse-medicine-text")
def parse_medicine_text(
    request: dict,
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """Parse OCR-extracted text to extract medicine information using Groq"""
    extracted_text = request.get("extracted_text")
    if not extracted_text:
        raise HTTPException(status_code=400, detail="Extracted text is required.")
    
    parsing_prompt = f"""
    You are an expert pharmaceutical AI assistant. Your task is to extract structured medicine information from OCR text.
    
    Extract the following fields from the text:
    - name (string, required): The medicine name
    - manufacturer (string, optional): The manufacturer company
    - strength (string, optional): The strength/dosage (e.g., "500mg", "10mg/5ml")
    - price (float, optional): The price if mentioned
    - lot_number (string, optional): Batch/Lot number if visible
    - expiry_date (string, optional): Expiry date in "YYYY-MM-DD" format if visible
    
    IMPORTANT RULES:
    - Return ONLY a valid JSON object with these fields
    - Use null for missing fields
    - For dates, convert to YYYY-MM-DD format
    - For strength, include units (mg, ml, etc.)
    - Be accurate and conservative - only extract clearly visible information
    
    OCR Text to parse:
    "{extracted_text}"
    
    Respond with JSON only:
    """
    
    try:
        response = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[{"role": "user", "content": parsing_prompt}],
            temperature=0.1,
            response_format={"type": "json_object"},
        )
        
        parsed_json_str = response.choices[0].message.content
        print(f"Groq parsed medicine data: {parsed_json_str}")
        parsed_data = json.loads(parsed_json_str)
        
        return parsed_data
        
    except Exception as e:
        print(f"Error parsing medicine text with Groq: {e}")
        raise HTTPException(status_code=400, detail=f"Could not parse the medicine text: {str(e)}")    