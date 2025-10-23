"""
FastAPI Demo Application for Jenkins CI/CD Pipeline
"""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import uvicorn

app = FastAPI(
    title="Jenkins Demo API",
    description="Modern FastAPI demo for Jenkins CI/CD pipeline",
    version="1.0.0"
)


class Item(BaseModel):
    """Item model"""
    id: Optional[int] = None
    name: str
    description: Optional[str] = None
    price: float
    in_stock: bool = True


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    message: str


# In-memory database
items_db: List[Item] = []
item_counter = 1


@app.get("/", response_model=HealthResponse)
async def root():
    """Root endpoint - health check"""
    return HealthResponse(
        status="ok",
        message="Jenkins Demo API is changed!"
    )


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        message="All systems operational"
    )


@app.get("/items", response_model=List[Item])
async def get_items():
    """Get all items"""
    return items_db


@app.get("/items/{item_id}", response_model=Item)
async def get_item(item_id: int):
    """Get a specific item by ID"""
    for item in items_db:
        if item.id == item_id:
            return item
    raise HTTPException(status_code=404, detail="Item not found")


@app.post("/items", response_model=Item, status_code=201)
async def create_item(item: Item):
    """Create a new item"""
    global item_counter
    item.id = item_counter
    item_counter += 1
    items_db.append(item)
    return item


@app.put("/items/{item_id}", response_model=Item)
async def update_item(item_id: int, updated_item: Item):
    """Update an existing item"""
    for idx, item in enumerate(items_db):
        if item.id == item_id:
            updated_item.id = item_id
            items_db[idx] = updated_item
            return updated_item
    raise HTTPException(status_code=404, detail="Item not found")


@app.delete("/items/{item_id}")
async def delete_item(item_id: int):
    """Delete anasdsadsadsadsa item"""
    for idx, item in enumerate(items_db):
        if item.id == item_id:
            items_db.pop(idx)
            return {"message": f"Item {item_id} deleted successfully"}
    raise HTTPException(status_code=404, detail="Item not found")


def calculate_discount(price: float, discount_percent: float) -> float:
    """Calculate discounted price"""
    if discount_percent < 0 or discount_percent > 100:
        raise ValueError("Discount must be between 0 and 100")
    return price * (1 - discount_percent / 100)


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)
