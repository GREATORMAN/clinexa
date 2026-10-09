from functools import lru_cache
from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    APP_NAME: str = "Clinexa"
    ENVIRONMENT: str = "development"
    API_V1_PREFIX: str = "/api/v1"
    DATABASE_URL: str = "sqlite:///./clinexa_dev.db"
    REDIS_URL: str = "redis://127.0.0.1:6379/0"
    SECRET_KEY: str = "development-only-change-me"
    ENCRYPTION_KEY: str = ""
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 14
    CORS_ORIGINS: str = "http://localhost:8080,http://127.0.0.1:8080"
    STORAGE_PATH: str = "./storage"
    MAX_UPLOAD_SIZE: int = 20 * 1024 * 1024
    OLLAMA_BASE_URL: str = "http://127.0.0.1:11434"
    OLLAMA_MODEL: str = "qwen3:1.7b"
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_FROM: str = ""
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    OCR_ENGINE: str = "tesseract"
    TESSERACT_CMD: str = ""
    model_config = SettingsConfigDict(env_file=(".env", "../.env"), env_file_encoding="utf-8", extra="ignore")

    @model_validator(mode="after")
    def production_configuration(self):
        if self.ENVIRONMENT.lower() in {"production", "prod"}:
            if self.SECRET_KEY == "development-only-change-me" or len(self.SECRET_KEY) < 32:
                raise ValueError("Production requires a random SECRET_KEY of at least 32 characters")
            if len(self.ENCRYPTION_KEY) < 32:
                raise ValueError("Production requires a separate ENCRYPTION_KEY of at least 32 characters")
            if not self.DATABASE_URL.startswith("postgresql"):
                raise ValueError("Production requires PostgreSQL")
            if not self.cors_origins_list or any(not origin.startswith("https://") for origin in self.cors_origins_list):
                raise ValueError("Production requires explicit HTTPS CORS origins")
        return self

    @property
    def cors_origins_list(self) -> list[str]:
        return [x.strip() for x in self.CORS_ORIGINS.split(",") if x.strip()]

@lru_cache
def get_settings() -> Settings:
    return Settings()
