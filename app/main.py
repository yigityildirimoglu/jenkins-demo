"""
FastAPI Demo Application for Jenkins CI/CD Pipeline
"""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import uvicorn
import logging  # Standart logging modülünü import et
import sys      # Logları stdout'a yönlendirmek için

# === Loglama Yapılandırması ===
# Logları INFO seviyesi ve üzeri olacak şekilde ayarla.
# Logları standart çıktıya (stdout) yönlendir. Docker bunu yakalayacak.
# Log formatını belirle: Zaman - Logger Adı - Seviye - Mesaj
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout  # Logların konsola yazdırılmasını sağla
)

# Bu modül için bir logger örneği al
logger = logging.getLogger(__name__)
# ============================

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
    """Root endpoint - health check HElLOOO"""
    # Örnek INFO seviyesi log: Bir istek geldiğinde bilgi ver.
    logger.info("Root endpoint '/' called.")
    return HealthResponse(
        status="ok",
        message="Jenkins Demooo API is running! Heyoooooo!"
    )


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    # Sağlık kontrolü endpoint'i çağrıldığında log yazdır.
    logger.info("Health check endpoint '/health' called.")
    return HealthResponse(
        status="healthy",
        message="All systems operational"
    )


@app.get("/items", response_model=List[Item])
async def get_items():
    """Get all items"""
    logger.info("Getting all items from '/items' endpoint.")
    return items_db


@app.get("/items/{item_id}", response_model=Item)
async def get_item(item_id: int):
    """Get a specific item by ID"""
    # DÜZELTME: Uzun satır ikiye bölündü (E501)
    logger.info(
        f"Attempting to retrieve item with ID: {item_id} "
        f"from '/items/{{item_id}}' endpoint."
    )
    for item in items_db:
        if item.id == item_id:
            logger.info(f"Item with ID {item_id} found: {item}")
            return item
    # Örnek ERROR seviyesi log: Öğe bulunamadığında hata logu yazdır.
    logger.error(f"Item with ID {item_id} not found.")
    raise HTTPException(status_code=404, detail="Item not found")


@app.post("/items", response_model=Item, status_code=201)
async def create_item(item: Item):
    """Create a new item"""
    global item_counter
    logger.info(f"Creating new item: {item.name}")
    item.id = item_counter
    item_counter += 1
    items_db.append(item)
    logger.info(f"Item '{item.name}' created with ID: {item.id}")
    return item


@app.put("/items/{item_id}", response_model=Item)
async def update_item(item_id: int, updated_item: Item):
    """Update an existing item"""
    logger.info(f"Attempting to update item with ID: {item_id}")
    for idx, item in enumerate(items_db):
        if item.id == item_id:
            updated_item.id = item_id
            items_db[idx] = updated_item
            logger.info(f"Item with ID {item_id} updated successfully.")
            return updated_item
    logger.error(f"Failed to update. Item with ID {item_id} not found.")
    raise HTTPException(status_code=404, detail="Item not found")


@app.delete("/items/{item_id}")
async def delete_item(item_id: int):
    """Delete an item"""
    logger.info(f"Attempting to delete item with ID: {item_id}")
    for idx, item in enumerate(items_db):
        if item.id == item_id:
            items_db.pop(idx)
            logger.info(f"Item {item_id} deleted successfully.")
            return {"message": f"Item {item_id} deleted successfully"}
    logger.error(f"Failed to delete. Item with ID {item_id} not found.")
    raise HTTPException(status_code=404, detail="Item not found")


def calculate_discount(price: float, discount_percent: float) -> float:
    """Calculate discounted price"""
    if discount_percent < 0 or discount_percent > 100:
        # Örnek WARNING seviyesi log: Geçersiz bir değer girildiğinde uyar.
        logger.warning(f"Invalid discount percentage provided: {discount_percent}")
        raise ValueError("Discount must be between 0 and 100")
    discounted_price = price * (1 - discount_percent / 100)
    # DÜZELTME: Uzun satır ikiye bölündü (E501) ve yorum öncesi boşluk düzeltildi (E261)
    logger.debug(
        f"Calculated discount: Original={price}, Percent={discount_percent}, "
        f"Discounted={discounted_price}"
    )  # DEBUG seviyesi loglar varsayılan olarak görünmez
    return discounted_price


if __name__ == "__main__":
    # Uygulama başlatıldığında bir log yazdır.
    logger.info("Starting Jenkins Demo API...")
    # Portu tekrar 8000 olarak düzelttim, Jenkinsfile'daki -p 8001:8000 ile eşleşmesi için.
    uvicorn.run(app, host="0.0.0.0", port=8001)
