from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    APP_NAME: str = "Clinexa"
    ENVIRONMENT: str = "development"
    API_V1_PREFIX: str = "/api/v1"
    DATABASE_URL: str = "sqlite:///./clinexa_dev.db"
    REDIS_URL: str = "redis://127.0.0.1:6379/0"
    SECRET_KEY: str = "development-only-change-me"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 14
    CORS_ORIGINS: str = "http://localhost:8080,http://127.0.0.1:8080"
    STORAGE_PATH: str = "./storage"
    MAX_UPLOAD_SIZE: int = 20 * 1024 * 1024
    OLLAMA_BASE_URL: str = "http://127.0.0.1:11434"
    OLLAMA_MODEL: str = "qwen3:1.7b"
    OCR_ENGINE: str = "tesseract"
    TESSERACT_CMD: str = ""
    model_config = SettingsConfigDict(env_file=(".env", "../.env"), env_file_encoding="utf-8", extra="ignore")

    @property
    def cors_origins_list(self) -> list[str]:
        return [x.strip() for x in self.CORS_ORIGINS.split(",") if x.strip()]

@lru_cache
def get_settings() -> Settings:
    return Settings()
