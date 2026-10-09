"""
Mobile Automation Logger for Appium Android E2E Testing.
Provides thread-safe multi-handler logging to console, logcat buffer, and rotating file.
"""
import logging
import sys
from logging.handlers import RotatingFileHandler
from automation.config.mobile_config import LOGS_DIR

_mobile_logger = None

def get_mobile_logger(name: str = "AppiumAndroidE2E") -> logging.Logger:
    """Returns singleton configured mobile logger."""
    global _mobile_logger
    if _mobile_logger is not None:
        return _mobile_logger

    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)
    logger.handlers.clear()

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
    log_file_path = LOGS_DIR / "appium-execution.log"
    file_handler = RotatingFileHandler(
        filename=str(log_file_path),
        maxBytes=15 * 1024 * 1024,
        backupCount=5,
        encoding="utf-8"
    )
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    _mobile_logger = logger
    return _mobile_logger
