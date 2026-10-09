"""Additive migration. Never drops tables or rewrites existing patient data."""
from app.core.database import Base, engine
import app.models  # noqa: F401


def main():
    Base.metadata.create_all(bind=engine)
    print("Clinexa V8: care-task table ready. Existing records preserved.")


if __name__ == "__main__":
    main()
