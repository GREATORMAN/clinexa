import json
from sqlalchemy.orm import Session
from app.models.audit import AuditLog

def log_action(db: Session, actor_user_id: str | None, action: str, resource: str,
               resource_id: str | None = None, result: str = "success", metadata: dict | None = None):
    db.add(AuditLog(actor_user_id=actor_user_id, action=action, resource=resource,
                    resource_id=resource_id, result=result,
                    metadata_json=json.dumps(metadata or {}, default=str)))
