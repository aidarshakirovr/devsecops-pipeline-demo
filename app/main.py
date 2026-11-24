"""In-memory service catalog.

The process keeps items in memory so the image has no database and no shell-outs.
That keeps the secure baseline small enough for the pipeline gates to stay readable.
"""

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

app = FastAPI(
    title="devsecops-demo",
    version="0.1.0",
    docs_url=None,
    redoc_url=None,
)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'"
        response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"
        response.headers["Cache-Control"] = "no-store"
        response.headers["Server"] = "devsecops-demo"
        return response


app.add_middleware(SecurityHeadersMiddleware)


class ItemIn(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    owner: str = Field(min_length=1, max_length=80)


class Item(ItemIn):
    id: int


_ITEMS: dict[int, Item] = {}
_NEXT_ID = 1


def reset_store() -> None:
    global _NEXT_ID
    _ITEMS.clear()
    _NEXT_ID = 1


@app.get("/")
def root() -> dict[str, str]:
    return {"service": "devsecops-demo"}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/items")
def list_items() -> list[Item]:
    return list(_ITEMS.values())


@app.post("/items", status_code=201)
def create_item(payload: ItemIn) -> Item:
    global _NEXT_ID
    item = Item(id=_NEXT_ID, name=payload.name, owner=payload.owner)
    _ITEMS[item.id] = item
    _NEXT_ID += 1
    return item


@app.get("/items/{item_id}")
def get_item(item_id: int) -> Item:
    item = _ITEMS.get(item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="not found")
    return item
