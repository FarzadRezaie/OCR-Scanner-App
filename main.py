
# app.openapi = custom_openapi
from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.utils import get_openapi
from pydantic import BaseModel
from datetime import datetime, timedelta
from pymongo import MongoClient
from passlib.context import CryptContext
from jose import JWTError, jwt
from fastapi import Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi import FastAPI
# -----------------------------
# MongoDB Atlas connection
# -----------------------------
MONGO_URI = "mongodb+srv://OCR_db_user:gydHqQV3TozuaQc8@cluster0.ubvfklc.mongodb.net/docsDB?retryWrites=true&w=majority"
client = MongoClient(MONGO_URI)
db = client["docsDB"]
users_collection = db["users"]

# -----------------------------
# Security settings
# -----------------------------
SECRET_KEY = "01faaa310c68a5f624859cbbe3989540d321e05fbe39b088ef975a04e7c1a845"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(data: dict, expires_delta: timedelta = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

# -----------------------------
# Pydantic models
# -----------------------------
class UserCreate(BaseModel):
    username: str
    password: str
    role: str = "user"

class UserLogin(BaseModel):
    username: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"

class UserOut(BaseModel):
    username: str
    role: str

class PasswordReset(BaseModel):
    username: str
    new_password: str
    role: str   # 👈 Add this line

# -----------------------------
# FastAPI app + Security
# -----------------------------
app = FastAPI(title="OCR App - Authentication System")

# -----------------------------
# CORS middleware for Flutter web
# -----------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 👈 allow all origins (or put "http://localhost:8000", "http://localhost:1234" etc.)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
bearer_scheme = HTTPBearer(description="Paste the raw JWT token received from /login. Example: eyJhbGciOiJI...")

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme)):
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        role: str = payload.get("role")
        if username is None:
            raise HTTPException(status_code=401, detail="Invalid token")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

    user = users_collection.find_one({"username": username})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return {"username": user["username"], "role": user["role"]}

def require_admin(current_user: dict = Depends(get_current_user)):
    if current_user["role"] != "admin":
        raise HTTPException(status_code=403, detail="You need admin permission")
    return current_user

# -----------------------------
# Routes
# -----------------------------
app = FastAPI()

@app.get("/")
def read_root():
    return {"status": "ok"}
@app.get("/")
def root():
    return {"message": "FastAPI server is running!"}

@app.post("/init-admin")
def init_admin(user: UserCreate):
    if users_collection.count_documents({}) > 0:
        raise HTTPException(status_code=400, detail="Admin already initialized")

    if user.role != "admin":
        raise HTTPException(status_code=400, detail="First account must be admin")

    hashed_pw = hash_password(user.password)
    users_collection.insert_one({
        "username": user.username,
        "password": hashed_pw,
        "role": "admin",
        "created_at": datetime.utcnow()
    })
    return {"msg": f"Initial admin '{user.username}' created successfully"}

@app.post("/register")
def register(user: UserCreate, admin: dict = Depends(require_admin)):
    if users_collection.find_one({"username": user.username}):
        raise HTTPException(status_code=400, detail="Username already exists")

    hashed_pw = hash_password(user.password)
    users_collection.insert_one({
        "username": user.username,
        "password": hashed_pw,
        "role": user.role,
        "created_at": datetime.utcnow()
    })
    return {"msg": f"User '{user.username}' created successfully by admin {admin['username']}"}


@app.post("/reset-password")
def reset_password(data: PasswordReset):
    # Only admins can reset
    if data.role.lower() != "admin":
        raise HTTPException(status_code=403, detail="You need admin permission")

    db_user = users_collection.find_one({"username": data.username})
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")

    new_hashed_pw = hash_password(data.new_password)
    users_collection.update_one(
        {"username": data.username},
        {"$set": {
            "password": new_hashed_pw,
            "updated_at": datetime.utcnow()
        }}
    )
    return {"msg": f"Password for '{data.username}' reset successfully"}


@app.post("/login", response_model=Token)
def login(user: UserLogin):
    db_user = users_collection.find_one({"username": user.username})
    if not db_user or not verify_password(user.password, db_user["password"]):
        raise HTTPException(status_code=401, detail="Invalid username or password")

    token = create_access_token({"sub": db_user["username"], "role": db_user["role"]})
    return {"access_token": token, "token_type": "bearer"}

@app.get("/me", response_model=UserOut)
def read_current_user(current_user: dict = Depends(get_current_user)):
    return current_user

@app.get("/test-token")
def test_token(current_user: dict = Depends(get_current_user)):
    return {"msg": f"Login successful! Welcome {current_user['role']}"}


# -----------------------------
# Dashboard Endpoints
# -----------------------------

@app.get("/users/count")
async def get_users_count(role: str = Query(...)):
    if role != "Admin":
        raise HTTPException(status_code=403, detail="Only admin allowed")
    count = db["users"].count_documents({})   # 👈 no await
    return {"count": count}

@app.get("/documents/count")
async def get_documents_count(role: str = Query(...)):
    if role != "Admin":
        raise HTTPException(status_code=403, detail="Only admin allowed")
    count = db["documents"].count_documents({})  # 👈 no await
    return {"count": count}

@app.get("/users/list")
def get_users_list(admin: dict = Depends(require_admin)):
    users = list(users_collection.find({}, {"_id": 0, "username": 1, "role": 1}))
    return {"users": users}

@app.get("/recent-activities")
def get_recent_activities(admin: dict = Depends(require_admin)):
    # Example: replace with real activity logs later
    activities = [
        {
            "user": "system",
            "role": "admin",
            "action": "Initial setup",
            "date": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S"),
        }
    ]
    return {"activities": activities}


# -----------------------------
# OpenAPI / Swagger customization
# -----------------------------
def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    openapi_schema = get_openapi(
        title=app.title,
        version="1.0.0",
        description=(
            "OCR + Authentication API\n\n"
            "**Authentication Flow:**\n"
            "1. Call `POST /init-admin` (only once, if DB is empty) to create the first admin.\n"
            "2. Call `POST /login` with username & password to get an `access_token`.\n"
            "3. Click the green **Authorize** button and paste the raw token.\n"
            "4. Now you can call protected endpoints (`/register`, `/reset-password`, `/me`, `/test-token`)."
        ),
        routes=app.routes,
    )

    openapi_schema["components"] = openapi_schema.get("components", {})
    openapi_schema["components"]["securitySchemes"] = {
        "bearerAuth": {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "JWT",
            "description": "Paste the raw JWT token here."
        }
    }

    # 🔐 Mark protected endpoints as requiring bearerAuth
    for path in ["/me", "/test-token", "/register", "/reset-password", "/users/count", "/documents/count",  "/users/list","/recent-activities",]:
        if path in openapi_schema["paths"]:
            for method in openapi_schema["paths"][path]:
                openapi_schema["paths"][path][method]["security"] = [{"bearerAuth": []}]

    app.openapi_schema = openapi_schema
    return app.openapi_schema

app.openapi = custom_openapi
