# schemas.py
from pydantic import BaseModel
from typing import Optional, List
from datetime import date

# --- Inventory Item Schemas (MOVE THESE TO THE TOP) ---
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

# --- User Schemas ---
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

# --- Category Schemas ---
class CategoryBase(BaseModel):
    name: str
    description: Optional[str] = None

class CategoryCreate(CategoryBase):
    pass

class Category(CategoryBase):
    id: int
    class Config:
        from_attributes = True

# --- Manufacturer Schemas ---
class ManufacturerBase(BaseModel):
    name: str
    contact_email: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    country: Optional[str] = None
    website: Optional[str] = None

class ManufacturerCreate(ManufacturerBase):
    pass

class Manufacturer(ManufacturerBase):
    id: int
    is_verified: bool = False
    class Config:
        from_attributes = True

# --- Medicine Schemas (Updated) ---
class MedicineBase(BaseModel):
    barcode: Optional[str] = None
    name: str
    strength: Optional[str] = None
    price: float
    expiry_date: date
    # Use IDs instead of strings for relationships
    manufacturer_id: Optional[int] = None

class MedicineCreate(MedicineBase):
    pass

class Medicine(MedicineBase):
    id: int
    inventory_items: List[InventoryItem] = []  # Now InventoryItem is defined
    manufacturer_details: Optional[Manufacturer] = None
    categories: List[Category] = []
    class Config:
        from_attributes = True

# Request/Response Schemas
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
        
# Updated SmartCreateRequest to use relational data
class SmartCreateRequest(BaseModel):
    # Medicine fields
    barcode: Optional[str] = None
    name: str
    strength: Optional[str] = None
    price: float
    expiry_date: date
    
    # Inventory fields
    lot_number: str
    quantity: int
    
    # Relational fields (can use names instead of IDs for convenience)
    manufacturer_name: Optional[str] = None
    category_names: List[str] = []  # List of category names
    
    # Keep backward compatibility with existing fields
    requires_prescription: bool = False
    storage_instructions: Optional[str] = None
    side_effects: Optional[str] = None
    
    class Config:
        from_attributes = True