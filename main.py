# main.py
from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from typing import List
import re
from datetime import datetime, date, timedelta # Added date and timedelta
from dateutil.parser import parse as parse_date # Added this import
import models, schemas
from database import SessionLocal, engine
from fastapi.responses import JSONResponse
import easyocr
import os
import json

# --- NEW IMPORTS FOR LOCAL CHATBOT ---
from transformers import pipeline
import torch
# -------------------------------------

models.Base.metadata.create_all(bind=engine)

# --- INITIALIZATIONS ---

# Initialize EasyOCR reader once
reader = easyocr.Reader(['en']) 

# Initialize the local TinyLlama chatbot pipeline once
# The first time the server starts, this will download the model (~2.2 GB)
chatbot_pipeline = pipeline(
    "text-generation",
    model="TinyLlama/TinyLlama-1.1B-Chat-v1.0",
    trust_remote_code=True,
    torch_dtype=torch.float16,
    device_map="auto",
)

app = FastAPI(
    title="Pharmaceutical Inventory Management API",
    description="API for managing pharmacy inventory, orders, and more.",
    version="1.0.0",
)

# --- HELPER FUNCTIONS ---

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

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

def find_lot_number(text_block: str): # Added this function from our discussion
    lot_pattern = r'(?:Batch|Lot|B\.?No)\.?\s*:?\s*([\w\-]+)'
    match = re.search(lot_pattern, text_block, re.IGNORECASE)
    if match:
        return match.group(1)
    return None

def parse_gs1_string(data: str) -> dict:
    parsed_data = {}
    gtin_match = re.search(r'\(01\)(\d+)', data)
    if gtin_match:
        parsed_data['gtin'] = gtin_match.group(1)
    lot_match = re.search(r'\(10\)([\w-]+)', data)
    if lot_match:
        parsed_data['lot_number'] = lot_match.group(1)
    expiry_match = re.search(r'\(17\)(\d{6})', data)
    if expiry_match:
        try:
            date_str = expiry_match.group(1)
            parsed_data['expiry_date'] = datetime.strptime(date_str, '%y%m%d').date()
        except ValueError:
            pass
    return parsed_data

# --- DATABASE FUNCTIONS FOR CHATBOT TOOLS ---

def get_stock_quantity_from_db(medicine_name: str, db: Session):
    """Looks up the total quantity of a medicine by its name."""
    print(f"DATABASE: Querying stock for {medicine_name}")
    medicine = db.query(models.Medicine).filter(models.Medicine.name.ilike(f"%{medicine_name}%")).first()
    if not medicine:
        return f"Medicine '{medicine_name}' not found."
    total_quantity = sum(item.quantity for item in medicine.inventory_items)
    return json.dumps({"medicine_name": medicine.name, "total_quantity": total_quantity})

def find_expiring_medicines_from_db(days_limit: int, db: Session):
    """Finds medicines with batches expiring within a certain number of days."""
    print(f"DATABASE: Querying for medicines expiring within {days_limit} days")
    expiry_threshold = date.today() + timedelta(days=days_limit)
    expiring_items = db.query(models.InventoryItem).filter(models.InventoryItem.expiry_date <= expiry_threshold).all()
    if not expiring_items:
        return "No medicines are expiring soon."
    results = [{"medicine_name": item.medicine.name, "lot_number": item.lot_number, "expiry_date": item.expiry_date.isoformat()} for item in expiring_items]
    return json.dumps(results)


# --- API ENDPOINTS ---

@app.post("/medicines/", response_model=schemas.Medicine, status_code=201)
def create_medicine(medicine: schemas.MedicineCreate, db: Session = Depends(get_db)):
    # ... (function is correct)
    if medicine.barcode:
        existing_medicine = db.query(models.Medicine).filter(models.Medicine.barcode == medicine.barcode).first()
        if existing_medicine:
            raise HTTPException(status_code=400, detail="Medicine with this barcode already exists.")
    db_medicine = models.Medicine(**medicine.dict())
    db.add(db_medicine)
    db.commit()
    db.refresh(db_medicine)
    return db_medicine

@app.get("/medicines/", response_model=List[schemas.Medicine])
def read_medicines(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    medicines = db.query(models.Medicine).offset(skip).limit(limit).all()
    return medicines

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
    # ... (function is correct)
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
    # ... (function is correct)
    db_medicine = db.query(models.Medicine).filter(models.Medicine.id == medicine_id).first()
    if not db_medicine:
        raise HTTPException(status_code=404, detail="Medicine not found.")
    db.query(models.InventoryItem).filter(models.InventoryItem.medicine_id == medicine_id).delete()
    db.delete(db_medicine)
    db.commit()
    return {"message": "Medicine and all associated stock deleted successfully."}

@app.post("/medicines/smart-create", response_model=schemas.Medicine)
def smart_create_medicine_and_inventory(request: schemas.SmartCreateRequest, db: Session = Depends(get_db)):
    # ... (function is correct)
    new_medicine = models.Medicine(barcode=request.barcode, name=request.name, manufacturer=request.manufacturer, strength=request.strength, price=request.price, expiry_date=request.expiry_date)
    db.add(new_medicine)
    db.commit()
    db.refresh(new_medicine)
    new_inventory_item = models.InventoryItem(medicine_id=new_medicine.id, lot_number=request.lot_number, quantity=request.quantity, expiry_date=request.expiry_date)
    db.add(new_inventory_item)
    db.commit()
    db.refresh(new_medicine)
    return new_medicine

@app.post("/inventory/receive", response_model=schemas.InventoryItem, status_code=201)
def receive_inventory_item(item: schemas.InventoryItemCreate, db: Session = Depends(get_db)):
    # ... (function is correct)
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
    # ... (function is correct)
    parsed_data = parse_gs1_string(scan_data.gs1_data)
    if not all(k in parsed_data for k in ['gtin', 'lot_number', 'expiry_date']):
        raise HTTPException(status_code=400, detail="Incomplete GS1 data. GTIN, Lot, and Expiry are required.")
    gtin = parsed_data['gtin']
    medicine = db.query(models.Medicine).filter(models.Medicine.barcode == gtin).first()
    if not medicine:
        new_medicine = models.Medicine(barcode=gtin, name=f"New Medicine - GTIN {gtin}", manufacturer="Unknown", strength="N/A", price=0.0, expiry_date=parsed_data['expiry_date'])
        db.add(new_medicine)
        db.commit()
        db.refresh(new_medicine)
        medicine = new_medicine
    new_item = models.InventoryItem(medicine_id=medicine.id, lot_number=parsed_data['lot_number'], expiry_date=parsed_data['expiry_date'], quantity=scan_data.quantity)
    db.add(new_item)
    db.commit()
    db.refresh(new_item)
    return new_item

@app.post("/inventory/dispense")
def dispense_inventory_item(dispense_request: schemas.DispenseRequest, db: Session = Depends(get_db)):
    # ... (function is correct)
    db_item = db.query(models.InventoryItem).filter(models.InventoryItem.id == dispense_request.item_id).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Inventory item not found.")
    if db_item.quantity < dispense_request.quantity:
        raise HTTPException(status_code=400, detail="Insufficient stock to dispense this quantity.")
    db_item.quantity -= dispense_request.quantity
    if db_item.quantity == 0:
        medicine_id_to_check = db_item.medicine_id
        db.delete(db_item)
        db.commit()
        remaining_items = db.query(models.InventoryItem).filter(models.InventoryItem.medicine_id == medicine_id_to_check).count()
        if remaining_items ==.0:
            medicine_to_delete = db.query(models.Medicine).filter(models.Medicine.id == medicine_id_to_check).first()
            if medicine_to_delete:
                db.delete(medicine_to_delete)
                db.commit()
            return JSONResponse(status_code=200, content={"message": "Item dispensed and catalog entry removed as stock is zero."})
        return JSONResponse(status_code=200, content={"message": "Item dispensed and removed as stock is zero."})
    else:
        db.commit()
        db.refresh(db_item)
        return db_item

@app.post("/inventory/restock", response_model=schemas.InventoryItem)
def restock_inventory_item(restock_request: schemas.RestockRequest, db: Session = Depends(get_db)):
    # ... (function is correct)
    db_item = db.query(models.InventoryItem).filter(models.InventoryItem.id == restock_request.item_id).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Inventory item not found.")
    db_item.quantity += restock_request.quantity
    db.commit()
    db.refresh(db_item)
    return db_item

@app.post("/ocr/extract-text")
def extract_text_from_image(file: UploadFile = File(...)):
    # ... (function is correct and updated)
    image_bytes = file.file.read()
    result = reader.readtext(image_bytes)
    full_text = " ".join([text for bbox, text, conf in result])
    if not full_text:
        raise HTTPException(status_code=400, detail="No text detected in the image.")
    found_date = find_and_parse_date(full_text)
    found_price = find_and_parse_price(full_text)
    found_lot = find_lot_number(full_text)
    return {"found_text": full_text, "parsed_date": found_date.isoformat() if found_date else None, "parsed_price": found_price, "parsed_lot": found_lot}

# --- CHATBOT ENDPOINT (LOCAL MODEL VERSION) ---

@app.post("/chatbot/query")
def chatbot_query(request: dict, db: Session = Depends(get_db)):
    """
    Handles chatbot queries using a local TinyLlama model.
    Robustly extracts JSON from model output and maps to the correct tool.
    """
    user_message = request.get("message")
    if not user_message:
        raise HTTPException(status_code=400, detail="Message is required.")

    # --- Step 1: LLM call to determine tool ---
    tool_prompt = f"""
    <|system|>
    You are an expert AI assistant. Your task is to identify the correct tool and parameters to use based on a user's question.
    Available tools:
      - get_stock_quantity(medicine_name: str)
      - find_expiring_medicines(days_limit: int)
    Respond ONLY with a valid JSON object containing one of the tool names as the key.
    Example:
      {{ "get_stock_quantity": {{ "medicine_name": "Paracetamol" }} }}
    Do not add any extra text, explanation, or markdown.
    </s>
    <|user|>
    {user_message}</s>
    <|assistant|>
    """

    response = chatbot_pipeline(
        tool_prompt,
        max_new_tokens=150,
        eos_token_id=chatbot_pipeline.tokenizer.eos_token_id
    )
    generated_text = response[0]['generated_text']

    try:
        assistant_response = generated_text.split("<|assistant|>")[1].strip()

        # --- Extract JSON robustly ---
        json_match = re.search(r'\{.*\}', assistant_response, re.DOTALL)
        if not json_match:
            raise ValueError("No JSON block found in the model's response")

        tool_json_str = json_match.group(0)
        print("--------- EXTRACTED JSON STR ---------")
        print(tool_json_str)
        print("------------------------------------")

        tool_data = json.loads(tool_json_str)

        # --- Map JSON keys to functions ---
        result = "I'm sorry, I couldn't understand that request."

        # Known tool names
        available_tools = {
            "get_stock_quantity": get_stock_quantity_from_db,
            "find_expiring_medicines": find_expiring_medicines_from_db
        }

        # Step 1: Direct match
        for tool_name, func in available_tools.items():
            if tool_name in tool_data:
                args = tool_data[tool_name]
                if tool_name == "get_stock_quantity":
                    result = func(args.get("medicine_name", ""), db)
                elif tool_name == "find_expiring_medicines":
                    result = func(args.get("days_limit", 7), db)
                return {"response": result}

        # Step 2: Fallback mapping for unexpected keys
        # e.g., {"expiry_date": "2022-01-01T00:00:00.000Z"}
        if "expiry_date" in tool_data:
            try:
                expiry_date = parse_date(tool_data["expiry_date"]).date()
                days_limit = max((expiry_date - date.today()).days, 0)
                result = find_expiring_medicines_from_db(days_limit, db)
            except Exception as e:
                result = f"Invalid expiry_date format: {e}"
        elif "medicine_name" in tool_data:
            result = get_stock_quantity_from_db(tool_data["medicine_name"], db)

        return {"response": result}

    except (json.JSONDecodeError, AttributeError, IndexError, ValueError) as e:
        print(f"ERROR PARSING TOOL JSON: {e}")
        return {"response": "I'm sorry, I couldn't understand that request. Could you please rephrase?"}
