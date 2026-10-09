import base64,hashlib,hmac,secrets,struct,time
from cryptography.fernet import Fernet
from app.core.config import get_settings

def cipher():
    return Fernet(base64.urlsafe_b64encode(hashlib.sha256(((get_settings().ENCRYPTION_KEY or get_settings().SECRET_KEY)+':mfa').encode()).digest()))
def new_secret():return base64.b32encode(secrets.token_bytes(20)).decode().rstrip('=')
def code(secret,counter):
    key=base64.b32decode(secret+'='*((8-len(secret)%8)%8))
    digest=hmac.new(key,struct.pack('>Q',counter),hashlib.sha1).digest();offset=digest[-1]&15
    return str((struct.unpack('>I',digest[offset:offset+4])[0]&0x7fffffff)%1000000).zfill(6)
def verify(secret,value,last=-1):
    counter=int(time.time()//30)
    for c in (counter,counter-1,counter+1):
        if c>last and hmac.compare_digest(code(secret,c),str(value)):return c
    return None
