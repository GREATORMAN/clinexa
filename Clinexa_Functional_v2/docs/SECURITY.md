# Production security checklist

The codebase includes application-level controls, but a real deployment should also use:
TLS, managed secrets, encrypted volumes/backups, reverse-proxy rate limiting, malware
scanning for uploads, centralized monitoring, immutable audit retention, tested restores,
strict CORS, production database credentials, penetration testing, privacy policies and
role/object-level access reviews.
