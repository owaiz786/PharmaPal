# models.py
from sqlalchemy import Column, Integer, String, Float, Date, ForeignKey
from sqlalchemy.orm import relationship
from database import Base # Use a relative import

# Model for the medicine catalog
class Medicine(Base):
    __tablename__ = "medicines"

    id = Column(Integer, primary_key=True, index=True)
    barcode = Column(String, unique=True, index=True, nullable=True)
    name = Column(String, index=True, nullable=False)
    manufacturer = Column(String)
    strength = Column(String)
    
    # --- ADD THESE TWO LINES BACK ---
    price = Column(Float, nullable=False)
    expiry_date = Column(Date, nullable=False)
    # --------------------------------

    inventory_items = relationship("InventoryItem", back_populates="medicine")

# Model for a specific batch of medicine in stock
class InventoryItem(Base):
    __tablename__ = "inventory_items"

    id = Column(Integer, primary_key=True, index=True)
    lot_number = Column(String, nullable=False, index=True)
    expiry_date = Column(Date, nullable=False)
    quantity = Column(Integer, nullable=False)
    
    # This is the foreign key linking to the 'medicines' table
    medicine_id = Column(Integer, ForeignKey("medicines.id"))

    # This completes the relationship link
    medicine = relationship("Medicine", back_populates="inventory_items")