"""Per-process limits for a single-worker deployment. Use a shared gateway at scale."""
from collections import defaultdict,deque
from threading import Lock
from time import monotonic
from starlette.responses import JSONResponse
class RateLimit:
    def __init__(self):self.events=defaultdict(deque);self.lock=Lock()
    def allow(self,key,limit,period):
        now=monotonic()
        with self.lock:
            q=self.events[key]
            while q and q[0]<now-period:q.popleft()
            if len(q)>=limit:return False
            q.append(now)
            if len(self.events)>5000:
                for k in list(self.events):
                    if not self.events[k] or self.events[k][-1]<now-3600:del self.events[k]
            return True
limiter=RateLimit()
async def middleware(request,call_next):
    path=request.url.path
    if request.method=='POST' and any(path.endswith(p) for p in ['/auth/login','/auth/register','/auth/refresh','/auth/forgot-password','/auth/reset-password','/account/mfa/setup','/account/mfa/confirm','/account/mfa/disable']):
        ip=request.client.host if request.client else 'unknown'
        if not limiter.allow((ip,path),30 if path.endswith('/refresh') else 10,60):
            return JSONResponse({'detail':'Too many attempts. Try again in one minute.'},429,headers={'Retry-After':'60'})
    return await call_next(request)
