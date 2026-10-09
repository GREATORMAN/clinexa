"""Run `python -m app.cli.worker` periodically. Claims a bounded batch; logs no PHI."""
import json,smtplib,ssl
from email.message import EmailMessage
from sqlalchemy import select,update
from app.core.database import SessionLocal
from app.core.config import get_settings
from app.models.workspace import Job
from app.services.mfa import cipher

def run():
    settings=get_settings()
    if not settings.SMTP_HOST or not settings.SMTP_FROM:
        print('Mail worker unavailable: configure SMTP_HOST and SMTP_FROM. No jobs consumed.');return 2
    with SessionLocal() as db:
        ids=list(db.scalars(select(Job.id).where(Job.state.in_(['queued','retry']),Job.attempts<5).order_by(Job.created_at).limit(25)))
    for id in ids:
        with SessionLocal() as db:
            changed=db.execute(update(Job).where(Job.id==id,Job.state.in_(['queued','retry'])).values(state='running',attempts=Job.attempts+1))
            if changed.rowcount!=1:db.rollback();continue
            db.commit();job=db.get(Job,id)
            try:
                data=json.loads(cipher().decrypt(job.payload.encode()))
                if job.kind!='password_reset_email':raise ValueError('unsupported_job')
                email=EmailMessage();email['From']=settings.SMTP_FROM;email['To']=data['email'];email['Subject']='Reset your Clinexa password'
                email.set_content('Your Clinexa reset token (valid for 30 minutes):\n\n'+data['token']+'\n\nOpen Clinexa, choose Reset password and paste this token. If you did not request this, ignore this message.')
                with smtplib.SMTP(settings.SMTP_HOST,settings.SMTP_PORT,timeout=20) as smtp:
                    smtp.starttls(context=ssl.create_default_context())
                    if settings.SMTP_USER:smtp.login(settings.SMTP_USER,settings.SMTP_PASSWORD)
                    smtp.send_message(email)
                job.state='completed';job.payload='';job.error_code=None
            except Exception:
                job.state='retry' if job.attempts<5 else 'failed';job.error_code='mail_delivery_failed'
            db.commit()
    print(f'Mail worker processed {len(ids)} claimed candidates.');return 0
if __name__=='__main__':raise SystemExit(run())
