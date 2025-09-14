# main.py
from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
import re
from datetime import datetime
import models, schemas
from database import SessionLocal, engine
from fastapi.responses import JSONResponse


models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Pharmaceutical Inventory Management API",
    description="API for managing pharmacy inventory, orders, and more.",
    version="1.0.0",
)

# Dependency to get a database session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def parse_gs1_string(data: str) -> dict:
    """
    Parses a GS1 data string to extract GTIN, Lot, and Expiry Date.
    GS1 Application Identifiers (AIs):
    (01) GTIN (Product ID)
    (10) Lot Number
    (17) Expiry Date (YYMMDD)
    """
    parsed_data = {}
    # FNC1 group separator character, often represented by <GS> or a non-printable char
    # We'll split by the Application Identifiers (AIs) like (01), (10), etc.
    
    # Find GTIN (AI 01)
    gtin_match = re.search(r'\(01\)(\d+)', data)
    if gtin_match:
        parsed_data['gtin'] = gtin_match.group(1)

    # Find Lot Number (AI 10)
    lot_match = re.search(r'\(10\)([\w-]+)', data)
    if lot_match:
        parsed_data['lot_number'] = lot_match.group(1)

    # Find Expiry Date (AI 17) - format is YYMMDD
    expiry_match = re.search(r'\(17\)(\d{6})', data)
    if expiry_match:
        try:
            # Convert YYMMDD string to a proper date object
            date_str = expiry_match.group(1)
            parsed_data['expiry_date'] = datetime.strptime(date_str, '%y%m%d').date()
        except ValueError:
            pass # Ignore if date is invalid

    return parsed_data


# --- Medicine Endpoints ---

@app.post("/medicines/", response_model=schemas.Medicine, status_code=201)
def create_medicine(medicine: schemas.MedicineCreate, db: Session = Depends(get_db)):
    """
    Create a new medicine in the catalog. This does not add stock.
    """
    # Check if a medicine with the same barcode already exists (if barcode is provided)
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
    """
    Retrieve all medicines from the catalog, including their stock details.
    """
    medicines = db.query(models.Medicine).offset(skip).limit(limit).all()
    return medicines


@app.get("/medicines/{medicine_id}", response_model=schemas.Medicine)
def read_medicine(medicine_id: int, db: Session = Depends(get_db)):
    """
    Retrieve a single medicine by its ID, including its stock details.
    """
    db_medicine = db.query(models.Medicine).filter(models.Medicine.id == medicine_id).first()
    if db_medicine is None:
        raise HTTPException(status_code=404, detail="Medicine not found")
    return db_medicine


@app.get("/medicines/barcode/{barcode}", response_model=schemas.Medicine)
def read_medicine_by_barcode(barcode: str, db: Session = Depends(get_db)):
    """
    Retrieve a single medicine by its barcode.
    """
    db_medicine = db.query(models.Medicine).filter(models.Medicine.barcode == barcode).first()
    if db_medicine is None:
        raise HTTPException(status_code=404, detail="Medicine with this barcode not found")
    return db_medicine


# --- Inventory Endpoints ---

@app.post("/inventory/receive", response_model=schemas.InventoryItem, status_code=201)
def receive_inventory_item(item: schemas.InventoryItemCreate, db: Session = Depends(get_db)):
    """
    Receive a new batch of medicine into inventory.
    """
    # First, check if the medicine exists
    db_medicine = db.query(models.Medicine).filter(models.Medicine.id == item.medicine_id).first()
    if not db_medicine:
        raise HTTPException(status_code=404, detail=f"Medicine with id {item.medicine_id} not found.")

    db_item = models.InventoryItem(**item.dict())
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

@app.post("/inventory/dispense")
def dispense_inventory_item(dispense_request: schemas.DispenseRequest, db: Session = Depends(get_db)):
    """
    Dispense a specific quantity from an inventory item.
    If quantity becomes zero, the item is deleted.
    If it was the last item for a medicine, the medicine is also deleted.
    """
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

        # --- NEW AUTO-DELETE LOGIC ---
        # Check if any other inventory items exist for this medicine
        remaining_items = db.query(models.InventoryItem).filter(models.InventoryItem.medicine_id == medicine_id_to_check).count()
        
        if remaining_items == 0:
            print(f"Last stock item for medicine ID {medicine_id_to_check} depleted. Deleting medicine catalog entry.")
            medicine_to_delete = db.query(models.Medicine).filter(models.Medicine.id == medicine_id_to_check).first()
            if medicine_to_delete:
                db.delete(medicine_to_delete)
                db.commit()
            return JSONResponse(status_code=200, content={"message": "Item dispensed and catalog entry removed as stock is zero."})
        # --- END OF NEW LOGIC ---
        
        return JSONResponse(status_code=200, content={"message": "Item dispensed and removed as stock is zero."})
    else:
        db.commit()
        db.refresh(db_item)
        return db_item

@app.delete("/medicines/{medicine_id}", status_code=200)
def delete_medicine(medicine_id: int, db: Session = Depends(get_db)):
    """
    Deletes a medicine and all of its associated inventory items.
    """
    db_medicine = db.query(models.Medicine).filter(models.Medicine.id == medicine_id).first()

    if not db_medicine:
        raise HTTPException(status_code=404, detail="Medicine not found.")

    # --- CRUCIAL STEP: Delete all child inventory items first ---
    # This is required to satisfy the foreign key constraint.
    db.query(models.InventoryItem).filter(models.InventoryItem.medicine_id == medicine_id).delete()

    # Now, delete the parent medicine object
    db.delete(db_medicine)
    
    db.commit()

    return {"message": "Medicine and all associated stock deleted successfully."}
@app.post("/inventory/receive-gs1", response_model=schemas.InventoryItem)
def receive_inventory_from_gs1_scan(scan_data: schemas.GS1ScanRequest, db: Session = Depends(get_db)):
    """
    Receives a raw GS1 scan, parses it, finds the medicine in the catalog
    (OR CREATES IT IF IT DOESN'T EXIST), and adds the item to inventory.
    """
    parsed_data = parse_gs1_string(scan_data.gs1_data)

    # Validate that we got the required data from the QR code
    if not all(k in parsed_data for k in ['gtin', 'lot_number', 'expiry_date']):
        raise HTTPException(status_code=400, detail="Incomplete GS1 data. GTIN, Lot, and Expiry are required.")

    gtin = parsed_data['gtin']

    # --- START OF THE NEW LOGIC ---

    # Try to find the medicine in our catalog using the GTIN (barcode)
    medicine = db.query(models.Medicine).filter(models.Medicine.barcode == gtin).first()
    
    # If the medicine is NOT found...
    if not medicine:
        # Create a new medicine catalog entry automatically
        print(f"Medicine with GTIN {gtin} not found. Creating a new catalog entry.")
        
        new_medicine = models.Medicine(
            barcode=gtin,
            name=f"New Medicine - GTIN {gtin}", # Placeholder name
            manufacturer="Unknown",              # Placeholder manufacturer
            strength="N/A",                      # Placeholder strength
            price=0.0,                           # Default price, can be updated later
            expiry_date=parsed_data['expiry_date'] # Use expiry from QR as a default
        )
        db.add(new_medicine)
        db.commit()
        db.refresh(new_medicine)
        
        # Use this newly created medicine for the inventory item
        medicine = new_medicine

    # --- END OF THE NEW LOGIC ---

    # Now, whether the medicine was found or newly created, 'medicine' holds a valid record.
    # Proceed to create the new inventory item.
    new_item = models.InventoryItem(
        medicine_id=medicine.id,
        lot_number=parsed_data['lot_number'],
        expiry_date=parsed_data['expiry_date'],
        quantity=scan_data.quantity
    )

    db.add(new_item)
    db.commit()
    db.refresh(new_item)
    
    # Return the newly created inventory item
    return new_item

@app.post("/inventory/restock", response_model=schemas.InventoryItem)
def restock_inventory_item(restock_request: schemas.RestockRequest, db: Session = Depends(get_db)):
    """
    Adds a specific quantity to an existing inventory item.
    """
    db_item = db.query(models.InventoryItem).filter(models.InventoryItem.id == restock_request.item_id).first()

    if not db_item:
        raise HTTPException(status_code=404, detail="Inventory item not found.")
    
    # Add the quantity
    db_item.quantity += restock_request.quantity
    db.commit()
    db.refresh(db_item)
    return db_item

@app.put("/medicines/{medicine_id}", response_model=schemas.Medicine)
def update_medicine_details(medicine_id: int, medicine_update: schemas.MedicineCreate, db: Session = Depends(get_db)):
    """
    Update the details of a medicine catalog item.
    """
    db_medicine = db.query(models.Medicine).filter(models.Medicine.id == medicine_id).first()

    if not db_medicine:
        raise HTTPException(status_code=404, detail="Medicine not found.")

    # Update the fields from the request body
    update_data = medicine_update.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_medicine, key, value)

    db.commit()
    db.refresh(db_medicine)
    return db_medicine