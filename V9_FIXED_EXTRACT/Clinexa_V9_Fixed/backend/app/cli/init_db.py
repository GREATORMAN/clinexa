from app.core.database import Base,engine
import app.models
if __name__=="__main__":
    Base.metadata.create_all(bind=engine);print("Clinexa database initialized.")
