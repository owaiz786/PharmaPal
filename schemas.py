# schemas.py
from pydantic import BaseModel
from typing import Optional, List
from datetime import date

# --- Inventory Item Schemas ---
class UserBase(BaseModel):
    username: str

class UserCreate(UserBase):
    password: str

class User(UserBase):
    id: int
    is_active: bool

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None
class InventoryItemBase(BaseModel):
    lot_number: str
    expiry_date: date
    quantity: int

class InventoryItemCreate(InventoryItemBase):
    medicine_id: int

class InventoryItem(InventoryItemBase):
    id: int
    medicine_id: int

    class Config:
         from_attributes = True


# --- Medicine Schemas (Updated) ---

class MedicineBase(BaseModel):
    barcode: Optional[str] = None
    name: str
    manufacturer: Optional[str] = None
    strength: Optional[str] = None
    
    # --- ADD THESE TWO LINES BACK ---
    price: float
    expiry_date: date
    # --------------------------------


class MedicineCreate(MedicineBase):
    pass

# The response schema for a Medicine now includes a list of its inventory items
class Medicine(MedicineBase):
    id: int
    inventory_items: List[InventoryItem] = []
    
class DispenseRequest(BaseModel):
    item_id: int
    quantity: int    

class RestockRequest(BaseModel):
    item_id: int
    quantity: int
class GS1ScanRequest(BaseModel):
    gs1_data: str
    quantity: int
    class Config:
        from_attributes = True
        
class SmartCreateRequest(BaseModel):
    # Fields for the Medicine catalog item
    barcode: Optional[str] = None
    name: str
    manufacturer: Optional[str] = None
    strength: Optional[str] = None
    price: float
    
    # Fields for the first InventoryItem batch
    lot_number: str
    quantity: int
    expiry_date: date        