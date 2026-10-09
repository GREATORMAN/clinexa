# Infrastructure setup

This source has not been deployed. The container/Compose/Hosting files are starting configurations, not provisioned infrastructure.

## PostgreSQL locally
Set POSTGRES_PASSWORD and a random SECRET_KEY (32+ characters) in your shell environment. URL-encode special password characters when constructing DATABASE_URL. Run `docker compose up -d db`, then `docker compose run --rm api python -m app.cli.migrate` and `docker compose up -d api`. Seed controlled staff accounts through the existing bootstrap tool only in development. Do not publish its demo accounts.

## Firebase Hosting
Build Flutter web with the HTTPS API URL:
`flutter build web --release --dart-define=CLINEXA_API_URL=https://YOUR_API_HOST`
Then from the deploy folder: `firebase deploy --only hosting --project YOUR_PROJECT_ID`.

## Cloud Run requirements
Build the backend Dockerfile, push it to Artifact Registry and deploy it with one worker per instance. Before real use: configure Cloud SQL PostgreSQL with a least-privilege database user, Secret Manager for separate SECRET_KEY/ENCRYPTION_KEY and mail secrets, HTTPS CORS origins, authenticated AI access, private persistent file storage, backups and monitoring.

The current document service writes local files. A Cloud Run filesystem is ephemeral; **do not put real documents on this deployment until private object storage is implemented**. Device reminders are local notifications, not FCM push. The included mail worker must be scheduled separately and given SMTP settings. Its retry jobs require operator inspection; there is no automatic recovery for a worker killed while a job is marked running.

No service accounts, Firebase keys, TURN credentials, signing keys or patient records are included.
