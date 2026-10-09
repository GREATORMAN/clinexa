import pytest
from app.core.rate_limit import limiter
@pytest.fixture(autouse=True)
def isolate_rate_limiter():
    limiter.events.clear()
    yield
    limiter.events.clear()
