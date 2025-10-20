from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from datetime import datetime, timedelta, timezone # Import timezone
from sqlalchemy.orm import Session
import os
from dotenv import load_dotenv
from typing import Optional
import models
import schemas
from database import get_db # Import the get_db dependency

load_dotenv()

# --- CONFIGURATION (Ensure these are set in your .env file) ---
SECRET_KEY = os.getenv("SECRET_KEY", "a_default_secret_key_for_development")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 # Increased for better user experience

# --- UTILITIES ---
# Passlib will now use the argon2 library, which is more secure and has no length limit
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")
# The tokenUrl MUST match the path of your login endpoint in main.py
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token") 

# --- CORE AUTHENTICATION FUNCTIONS ---

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifies a plain password against a hashed one."""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    """Hashes a plain password."""
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Creates a new JWT access token."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# --- DATABASE INTERACTION ---

def get_user_by_username(db: Session, username: str) -> Optional[models.User]:
    """
    Fetches a user from the PostgreSQL database by their username.
    This is the core database lookup function.
    """
    return db.query(models.User).filter(models.User.username == username).first()

# --- DEPENDENCY FOR SECURING ENDPOINTS (The most important part) ---

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    """
    Decodes the JWT token, validates it, and fetches the user from the database.
    This function will be used to protect your endpoints.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str | None = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    # --- THIS IS THE CRUCIAL DATABASE CALL ---
    user = get_user_by_username(db, username=username)
    if user is None:
        raise credentials_exception
    return user

async def get_current_active_user(current_user: models.User = Depends(get_current_user)):
    """

    A further dependency that checks if the user fetched from the token is active.
    """
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user