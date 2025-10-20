# main.py
from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
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
print(f"--- Loaded groq API Key: {os.getenv('GROQ_API_KEY')} ---")

# Initialize the client to point to DeepSeek's API endpoint
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

# Initialize the local TinyLlama chatbot pipeline
# This will download the model (~2.2 GB) on the very first run
print("Loading TinyLlama model...")


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

def _smart_create_db_entry(data: schemas.SmartCreateRequest, db: Session):
    """
    Safely creates a new medicine and its first inventory item.
    Handles both voice input (no barcode) and scan input (with barcode).
    Includes debugging prints and robust error handling.
    """
    # --- STEP 1: DEBUGGING PRINT ---
    # This will show us the exact data coming from Groq or the form
    print("\n--- ATTEMPTING TO SAVE TO DATABASE ---")
    print(f"Data received for validation: {data.dict()}")
    print("------------------------------------\n")
    
    try:
        # --- STEP 2: HANDLE BARCODE LOGIC (Your existing logic) ---
        # If a barcode is provided, check if the medicine already exists.
        if data.barcode:
            existing_medicine = db.query(models.Medicine).filter(models.Medicine.barcode == data.barcode).first()
            if existing_medicine:
                print(f"Found existing medicine '{existing_medicine.name}' via barcode. Adding new batch.")
                # If medicine exists, just add the new inventory batch to it
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

        # --- STEP 3: CREATE NEW MEDICINE (For voice or new scans) ---
        # If no barcode was provided (voice input), or if the barcode was new.
        print(f"Creating new medicine catalog entry for '{data.name}'.")
        new_medicine = models.Medicine(
            barcode=data.barcode,
            name=data.name,
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
        db.refresh(new_medicine) # Refresh the medicine object to include the new item
        
        print("--- DATABASE SAVE SUCCESSFUL ---")
        return new_medicine

    # --- STEP 5: ROBUST ERROR HANDLING ---
    except IntegrityError as e:
        # This catches specific database errors, like a UNIQUE constraint violation
        print(f"!!! DATABASE INTEGRITY ERROR: {e} !!!")
        db.rollback() # Important: undo the failed transaction
        raise HTTPException(status_code=409, detail=f"A medicine with this barcode ('{data.barcode}') already exists. The operation was cancelled.")
    except Exception as e:
        # This catches any other unexpected errors during the process
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

def get_stock_quantity_from_db(medicine_name: str, db: Session):
    medicine = db.query(models.Medicine).filter(models.Medicine.name.ilike(f"%{medicine_name}%")).first()
    if not medicine: return f"Medicine '{medicine_name}' not found."
    total_quantity = sum(item.quantity for item in medicine.inventory_items)
    return json.dumps({"medicine_name": medicine.name, "total_quantity": total_quantity})

def find_expiring_medicines_from_db(days_limit: int, db: Session):
    expiry_threshold = date.today() + timedelta(days=days_limit)
    expiring_items = db.query(models.InventoryItem).filter(models.InventoryItem.expiry_date <= expiry_threshold).all()
    if not expiring_items: return "No medicines are expiring soon."
    results = [{"medicine_name": item.medicine.name, "lot_number": item.lot_number, "expiry_date": item.expiry_date.isoformat()} for item in expiring_items]
    return json.dumps(results)

# --- API ENDPOINTS ---

@app.get("/medicines/", response_model=List[schemas.Medicine])
def read_medicines(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    medicines = db.query(models.Medicine).offset(skip).limit(limit).all()
    return medicines

# ... (All other endpoints like /medicines/{id}, /medicines/barcode/{barcode}, etc. are correct)
# ... The code below includes the corrected chatbot and all other working endpoints.

@app.get("/medicines/{medicine_id}", response_model=schemas.Medicine)
def read_medicine(medicine_id: int, db: Session = Depends(get_db)):
    db_medicine = db.query(models.Medicine).filter(models.Medicine.id == medicine_id).first()
    if db_medicine is None:
        raise HTTPException(status_code=404, detail="Medicine not found")
    return db_medicine

@app.get("/medicines/barcode/{barcode}", response_model=schemas.Medicine)
def read_medicine_by_barcode(barcode: str, db: Session = Depends(get_db)):
    db_medicine = db.query(models.Medicine).filter(models.Medicine.barcode == barcode).first()
    if db_medicine is None:
        raise HTTPException(status_code=404, detail="Medicine with this barcode not found")
    return db_medicine

@app.put("/medicines/{medicine_id}", response_model=schemas.Medicine)
def update_medicine_details(medicine_id: int, medicine_update: schemas.MedicineCreate, db: Session = Depends(get_db)):
    db_medicine = db.query(models.Medicine).filter(models.Medicine.id == medicine_id).first()
    if not db_medicine:
        raise HTTPException(status_code=404, detail="Medicine not found.")
    update_data = medicine_update.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_medicine, key, value)
    db.commit()
    db.refresh(db_medicine)
    return db_medicine

@app.delete("/medicines/{medicine_id}", status_code=200)
def delete_medicine(medicine_id: int, db: Session = Depends(get_db)):
    db_medicine = db.query(models.Medicine).filter(models.Medicine.id == medicine_id).first()
    if not db_medicine:
        raise HTTPException(status_code=404, detail="Medicine not found.")
    db.query(models.InventoryItem).filter(models.InventoryItem.medicine_id == medicine_id).delete()
    db.delete(db_medicine)
    db.commit()
    return {"message": "Medicine and all associated stock deleted successfully."}

@app.post("/medicines/smart-create", response_model=schemas.Medicine)
def smart_create_medicine_and_inventory(request: schemas.SmartCreateRequest, db: Session = Depends(get_db)):
    return _smart_create_db_entry(request, db)

@app.post("/inventory/receive", response_model=schemas.InventoryItem, status_code=201)
def receive_inventory_item(item: schemas.InventoryItemCreate, db: Session = Depends(get_db)):
    db_medicine = db.query(models.Medicine).filter(models.Medicine.id == item.medicine_id).first()
    if not db_medicine:
        raise HTTPException(status_code=404, detail=f"Medicine with id {item.medicine_id} not found.")
    db_item = models.InventoryItem(**item.dict())
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

@app.post("/inventory/receive-gs1", response_model=schemas.InventoryItem)
def receive_inventory_from_gs1_scan(scan_data: schemas.GS1ScanRequest, db: Session = Depends(get_db)):
    parsed_data = parse_gs1_string(scan_data.gs1_data)
    if not all(k in parsed_data for k in ['gtin', 'lot_number', 'expiry_date']):
        raise HTTPException(status_code=400, detail="Incomplete GS1 data.")
    gtin = parsed_data['gtin']
    medicine = db.query(models.Medicine).filter(models.Medicine.barcode == gtin).first()
    if not medicine:
        medicine = models.Medicine(barcode=gtin, name=f"New Medicine - GTIN {gtin}", manufacturer="Unknown", strength="N/A", price=0.0, expiry_date=parsed_data['expiry_date'])
        db.add(medicine)
        db.commit()
        db.refresh(medicine)
    new_item = models.InventoryItem(medicine_id=medicine.id, lot_number=parsed_data['lot_number'], expiry_date=parsed_data['expiry_date'], quantity=scan_data.quantity)
    db.add(new_item)
    db.commit()
    db.refresh(new_item)
    return new_item

@app.post("/inventory/dispense")
def dispense_inventory_item(dispense_request: schemas.DispenseRequest, db: Session = Depends(get_db)):
    db_item = db.query(models.InventoryItem).filter(models.InventoryItem.id == dispense_request.item_id).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Inventory item not found.")
    if db_item.quantity < dispense_request.quantity:
        raise HTTPException(status_code=400, detail="Insufficient stock.")
    db_item.quantity -= dispense_request.quantity
    if db_item.quantity == 0:
        medicine_id_to_check = db_item.medicine_id
        db.delete(db_item)
        db.commit()
        remaining_items = db.query(models.InventoryItem).filter(models.InventoryItem.medicine_id == medicine_id_to_check).count()
        if remaining_items == 0: # <-- TYPO FIXED
            medicine_to_delete = db.query(models.Medicine).filter(models.Medicine.id == medicine_id_to_check).first()
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
def restock_inventory_item(restock_request: schemas.RestockRequest, db: Session = Depends(get_db)):
    db_item = db.query(models.InventoryItem).filter(models.InventoryItem.id == restock_request.item_id).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Inventory item not found.")
    db_item.quantity += restock_request.quantity
    db.commit()
    db.refresh(db_item)
    return db_item

@app.post("/ocr/extract-text")
def extract_text_from_image(file: UploadFile = File(...)):
    image_bytes = file.file.read()
    result = reader.readtext(image_bytes)
    full_text = " ".join([text for bbox, text, conf in result])
    if not full_text:
        raise HTTPException(status_code=400, detail="No text detected.")
    found_date = find_and_parse_date(full_text)
    found_price = find_and_parse_price(full_text)
    found_lot = find_lot_number(full_text)
    return {"found_text": full_text, "parsed_date": found_date.isoformat() if found_date else None, "parsed_price": found_price, "parsed_lot": found_lot}

@app.post("/voice/process-audio", response_model=schemas.Medicine)
def process_voice_audio(db: Session = Depends(get_db), file: UploadFile = File(...)):
    """
    Receives an audio file, transcribes it with Whisper, uses the GROQ API
    to parse the text, and creates a new medicine and inventory item.
    """
    # --- STEP 1: Transcribe audio to text with Whisper (UNCHANGED) ---
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
    
    # This prompt tells Groq its job: act as a JSON extractor.
    parsing_prompt = f"""
    You are an expert AI assistant for pharmaceutical inventory. Your task is to extract structured data from a user's voice transcription.
    You must parse this text to extract the following fields:
    - name (string, required)
    - manufacturer (string, optional)
    - strength (string, optional)
    - price (float, required)
    - lot_number (string, required)
    - quantity (integer, required)
    - expiry_date (string, in "YYYY-MM-DD" format, required)
    - barcode (string, optional)

    You MUST respond ONLY with a single, valid JSON object containing these fields. Do not add any explanation or conversational text.

    User's transcribed text: "{transcribed_text}"
    """
    
    try:
        # Call the Groq client (the same one used by the chatbot)
        response = client.chat.completions.create(
            model="llama-3.1-8b-instant", # Using a fast and capable model on Groq
            messages=[{"role": "user", "content": parsing_prompt}],
            temperature=0.0, # We want deterministic JSON output, so no creativity
            response_format={"type": "json_object"}, # Ask Groq to guarantee JSON output
        )
        
        parsed_json_str = response.choices[0].message.content
        print(f"Groq parsed JSON: {parsed_json_str}")
        parsed_data = json.loads(parsed_json_str)

        # Validate and create a SmartCreateRequest object from the parsed JSON
        smart_request = schemas.SmartCreateRequest(**parsed_data)

        # --- STEP 3: Call our reusable helper to save to the database (UNCHANGED) ---
        return _smart_create_db_entry(smart_request, db)

    except Exception as e:
        print(f"Error processing voice utterance with Groq: {e}")
        # Provide a detailed error for debugging
        error_detail = str(e)
        if 'parsed_json_str' in locals():
            error_detail += f" | Raw Model Output: {parsed_json_str}"
        raise HTTPException(status_code=400, detail=f"Could not parse the voice input. Please be more specific. Details: {error_detail}")


@app.post("/chatbot/query")
def chatbot_query(request: dict, db: Session = Depends(get_db)):
    """Handles chatbot queries using the Groq API with function calling."""
    user_message = request.get("message")
    if not user_message:
        raise HTTPException(status_code=400, detail="Message is required.")
    
    if not client.api_key:
        print("!!! GROQ API KEY NOT LOADED. CHECK .ENV FILE. !!!")
        raise HTTPException(status_code=500, detail="API key not configured.")
    
    messages = [{"role": "user", "content": user_message}]
    
    # Define available tool functions
    available_functions = {
        "get_stock_quantity": get_stock_quantity_from_db,
        "find_expiring_medicines": find_expiring_medicines_from_db,
    }
    
    tools = [
        {
            "type": "function",
            "function": {
                "name": "get_stock_quantity",
                "description": "Get the total stock quantity for a specific medicine.",
                "parameters": {
                    "type": "object",
                    "properties": { 
                        "medicine_name": {"type": "string", "description": "The name of the medicine, e.g., 'Paracetamol'"}
                    },
                    "required": ["medicine_name"],
                },
            },
        },
        {
            "type": "function",
            "function": {
                "name": "find_expiring_medicines",
                "description": "Find all medicine batches that are expiring within a given number of days.",
                "parameters": {
                    "type": "object",
                    "properties": { 
                        "days_limit": {"type": "integer", "description": "Number of days from today to check for expiry, e.g., 30"}
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
                
                # Execute the function
                function_response = function_to_call(**function_args)
                
                # Append the result back to messages for AI continuation
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
