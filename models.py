# models.py
from sqlalchemy import Column, Integer, String, Float, Date, ForeignKey,Boolean
from sqlalchemy.orm import relationship
from database import Base # Use a relative import

# Model for the medicine catalog
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)

    # This creates the other side of the relationship
    medicines = relationship("Medicine", back_populates="owner")
class Medicine(Base):
    __tablename__ = "medicines"
    
    id = Column(Integer, primary_key=True, index=True)
    barcode = Column(String, unique=True, index=True, nullable=True)
    name = Column(String, index=True, nullable=False)
    manufacturer = Column(String)
    strength = Column(String)
    price = Column(Float, nullable=False)
    expiry_date = Column(Date, nullable=False)
    
    # --- ADD THIS RELATIONSHIP ---
    user_id = Column(Integer, ForeignKey("users.id"))
    owner = relationship("User", back_populates="medicines")
    # ---------------------------

    inventory_items = relationship("InventoryItem", back_populates="medicine", cascade="all, delete-orphan")

# --- UPDATE THE INVENTORYITEM MODEL ---
class InventoryItem(Base):
    __tablename__ = "inventory_items"

    id = Column(Integer, primary_key=True, index=True)
    lot_number = Column(String, nullable=False, index=True)
    expiry_date = Column(Date, nullable=False)
    quantity = Column(Integer, nullable=False)
    
    medicine_id = Column(Integer, ForeignKey("medicines.id"))
    medicine = relationship("Medicine", back_populates="inventory_items")