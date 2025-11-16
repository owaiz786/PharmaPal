# models.py
from sqlalchemy import Column, Integer, String, Float, Date, ForeignKey, Boolean, Text, Table
from sqlalchemy.orm import relationship
from database import Base

# Association table for many-to-many relationship between medicines and categories
medicine_category = Table(
    'medicine_category',
    Base.metadata,
    Column('medicine_id', Integer, ForeignKey('medicines.id'), primary_key=True),
    Column('category_id', Integer, ForeignKey('categories.id'), primary_key=True)
)

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    medicines = relationship("Medicine", back_populates="owner")

class Category(Base):
    __tablename__ = "categories"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    description = Column(Text, nullable=True)
    medicines = relationship("Medicine", secondary=medicine_category, back_populates="categories")

class Manufacturer(Base):
    __tablename__ = "manufacturers"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    contact_email = Column(String, nullable=True)
    phone = Column(String, nullable=True)
    address = Column(Text, nullable=True)
    country = Column(String, nullable=True)
    website = Column(String, nullable=True)
    is_verified = Column(Boolean, default=False)
    medicines = relationship("Medicine", back_populates="manufacturer_details")

class Medicine(Base):
    __tablename__ = "medicines"
    id = Column(Integer, primary_key=True, index=True)
    barcode = Column(String, unique=True, index=True, nullable=True)
    name = Column(String, index=True, nullable=False)
    strength = Column(String, nullable=True)
    price = Column(Float, nullable=False)
    expiry_date = Column(Date, nullable=False)
    
    # Foreign keys for relationships
    user_id = Column(Integer, ForeignKey("users.id"))
    manufacturer_id = Column(Integer, ForeignKey("manufacturers.id"), nullable=True)
    
    # Keep these for backward compatibility during migration
    requires_prescription = Column(Boolean, default=False)
    storage_instructions = Column(Text, nullable=True)
    side_effects = Column(Text, nullable=True)
    
    # Relationships
    owner = relationship("User", back_populates="medicines")
    manufacturer_details = relationship("Manufacturer", back_populates="medicines")
    categories = relationship("Category", secondary=medicine_category, back_populates="medicines")
    inventory_items = relationship("InventoryItem", back_populates="medicine", cascade="all, delete-orphan")

class InventoryItem(Base):
    __tablename__ = "inventory_items"
    id = Column(Integer, primary_key=True, index=True)
    lot_number = Column(String, nullable=False, index=True)
    expiry_date = Column(Date, nullable=False)
    quantity = Column(Integer, nullable=False)
    medicine_id = Column(Integer, ForeignKey("medicines.id"))
    medicine = relationship("Medicine", back_populates="inventory_items")