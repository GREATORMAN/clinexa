"""
Logging utility for Selenium E2E Automation Framework.
Provides structured multi-channel logging (console + rotating file).
"""
import logging
import sys
from pathlib import Path
from logging.handlers import RotatingFileHandler
from automation.config.config import LOGS_DIR

_logger = None

def get_logger(name: str = "ClinexaE2E") -> logging.Logger:
    """Returns singleton configured logger."""
    global _logger
    if _logger is not None:
        return _logger

    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)
    logger.handlers.clear()

    # Formatter
    formatter = logging.Formatter(
        fmt="[%(asctime)s] [%(levelname)-8s] [%(name)s:%(funcName)s:%(lineno)d] - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

    # Console Handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

    # File Handler
    log_file_path = LOGS_DIR / "automation.log"
    file_handler = RotatingFileHandler(
        filename=str(log_file_path),
        maxBytes=10 * 1024 * 1024, # 10 MB
        backupCount=5,
        encoding="utf-8"
    )
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    _logger = logger
    return _logger
