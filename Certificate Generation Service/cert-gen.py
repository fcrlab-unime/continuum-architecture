import os
from dotenv import load_dotenv
import shutil
from fastapi import FastAPI, HTTPException, Depends, Form
from fastapi.responses import FileResponse
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from passlib.context import CryptContext
import secrets
import uvicorn

load_dotenv()

app = FastAPI()
security = HTTPBasic()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

CERTS_DIR = os.getenv("CERTS_DIR")
ASSIGNED_CERTS_DIR = os.getenv("ASSIGNED_CERTS_DIR")
AUTH_USERNAME = os.getenv("AUTH_USERNAME")
AUTH_PASSWORD_HASH = pwd_context.hash(os.getenv("AUTH_PASSWORD"))
FLASK_HOST = os.getenv("FLASK_HOST")
FLASK_PORT = int(os.getenv("FLASK_PORT"))

def verify_credentials(credentials: HTTPBasicCredentials = Depends(security)):
    correct_username = secrets.compare_digest(credentials.username, AUTH_USERNAME)
    correct_password = pwd_context.verify(credentials.password, AUTH_PASSWORD_HASH)
    
    if not (correct_username and correct_password):
        raise HTTPException(
            status_code=401,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Basic"},
        )
    return credentials.username

@app.get("/status")
def status():
    return {"status": "Service is running"}

@app.post("/gen-cert")
def gen_cert(
    name: str = Form(...),
    username: str = Depends(verify_credentials)
):
    if not name:
        raise HTTPException(status_code=400, detail="Name parameter is required")

    try:
        cert_files = os.listdir(CERTS_DIR)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Certificates directory not found")
    
    if not cert_files:
        raise HTTPException(
            status_code=404,
            detail="No certificates available in the source directory, please contact UNIME"
        )

    cert_files.sort()
    cert_file = cert_files[0]
    cert_file_path = os.path.join(CERTS_DIR, cert_file)

    new_cert_name = f"{name}_{cert_file}"
    new_cert_path = os.path.join(ASSIGNED_CERTS_DIR, new_cert_name)

    try:
        shutil.copy(cert_file_path, new_cert_path)
        os.remove(cert_file_path)
        return FileResponse(
            path=new_cert_path,
            filename=f"{name}.ovpn",
            media_type="application/x-openvpn-profile"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host=FLASK_HOST, port=FLASK_PORT)
