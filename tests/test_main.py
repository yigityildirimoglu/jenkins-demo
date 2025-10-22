"""
Unit tests for FastAPI application
Coverage: >50% guaranteed
"""
import pytest
from fastapi.testclient import TestClient
from app.main import app, calculate_discount, items_db


@pytest.fixture
def client():
    """Create test client"""
    return TestClient(app)


@pytest.fixture(autouse=True)
def reset_db():
    """Reset database before each test"""
    items_db.clear()
    yield
    items_db.clear()


class TestHealthEndpoints:
    """Test health check endpoints"""

    def test_root_endpoint(self, client):
        """Test root endpoint returns healthy status"""
        response = client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert "Jenkins Demo API" in data["message"]

    def test_health_check_endpoint(self, client):
        """Test health check endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["message"] == "All systems operational"


class TestItemsCRUD:
    """Test Items CRUD operations"""

    def test_get_empty_items(self, client):
        """Test getting items when database is empty"""
        response = client.get("/items")
        assert response.status_code == 200
        assert response.json() == []

    def test_create_item(self, client):
        """Test creating a new item"""
        item_data = {
            "name": "Laptop",
            "description": "Gaming laptop",
            "price": 1500.00,
            "in_stock": True
        }
        response = client.post("/items", json=item_data)
        assert response.status_code == 201
        data = response.json()
        assert data["id"] == 1
        assert data["name"] == "Laptop"
        assert data["price"] == 1500.00

    def test_create_multiple_items(self, client):
        """Test creating multiple items"""
        items = [
            {"name": "Mouse", "price": 25.00},
            {"name": "Keyboard", "price": 75.00},
            {"name": "Monitor", "price": 300.00}
        ]

        for item in items:
            response = client.post("/items", json=item)
            assert response.status_code == 201

        response = client.get("/items")
        assert len(response.json()) == 3

    def test_get_item_by_id(self, client):
        """Test getting a specific item by ID"""
        # Create an item first
        item_data = {"name": "Phone", "price": 800.00}
        create_response = client.post("/items", json=item_data)
        item_id = create_response.json()["id"]

        # Get the item
        response = client.get(f"/items/{item_id}")
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == item_id
        assert data["name"] == "Phone"

    def test_get_nonexistent_item(self, client):
        """Test getting an item that doesn't exist"""
        response = client.get("/items/999")
        assert response.status_code == 404
        assert response.json()["detail"] == "Item not found"

    def test_update_item(self, client):
        """Test updating an existing item"""
        # Create an item
        item_data = {"name": "Tablet", "price": 500.00}
        create_response = client.post("/items", json=item_data)
        item_id = create_response.json()["id"]

        # Update the item
        updated_data = {
            "name": "Tablet Pro",
            "description": "Updated tablet",
            "price": 600.00,
            "in_stock": False
        }
        response = client.put(f"/items/{item_id}", json=updated_data)
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Tablet Pro"
        assert data["price"] == 600.00
        assert data["in_stock"] is False

    def test_update_nonexistent_item(self, client):
        """Test updating an item that doesn't exist"""
        updated_data = {"name": "Ghost", "price": 100.00}
        response = client.put("/items/999", json=updated_data)
        assert response.status_code == 404

    def test_delete_item(self, client):
        """Test deleting an item"""
        # Create an item
        item_data = {"name": "Headphones", "price": 150.00}
        create_response = client.post("/items", json=item_data)
        item_id = create_response.json()["id"]

        # Delete the item
        response = client.delete(f"/items/{item_id}")
        assert response.status_code == 200
        assert "deleted successfully" in response.json()["message"]

        # Verify it's deleted
        get_response = client.get(f"/items/{item_id}")
        assert get_response.status_code == 404

    def test_delete_nonexistent_item(self, client):
        """Test deleting an item that doesn't exist"""
        response = client.delete("/items/999")
        assert response.status_code == 404


class TestBusinessLogic:
    """Test business logic functions"""

    def test_calculate_discount_valid(self):
        """Test discount calculation with valid inputs"""
        assert calculate_discount(100.0, 10.0) == 90.0
        assert calculate_discount(200.0, 50.0) == 100.0
        assert calculate_discount(150.0, 20.0) == 120.0

    def test_calculate_discount_zero(self):
        """Test discount calculation with 0% discount"""
        assert calculate_discount(100.0, 0.0) == 100.0

    def test_calculate_discount_full(self):
        """Test discount calculation with 100% discount"""
        assert calculate_discount(100.0, 100.0) == 0.0

    def test_calculate_discount_invalid_negative(self):
        """Test discount calculation with negative discount"""
        with pytest.raises(ValueError, match="Discount must be between 0 and 100"):
            calculate_discount(100.0, -10.0)

    def test_calculate_discount_invalid_over_100(self):
        """Test discount calculation with discount > 100%"""
        with pytest.raises(ValueError, match="Discount must be between 0 and 100"):
            calculate_discount(100.0, 150.0)


class TestValidation:
    """Test input validation"""

    def test_create_item_missing_required_fields(self, client):
        """Test creating item with missing required fields"""
        invalid_data = {"description": "No name or price"}
        response = client.post("/items", json=invalid_data)
        assert response.status_code == 422  # Validation error

    def test_create_item_invalid_price(self, client):
        """Test creating item with invalid price type"""
        invalid_data = {
            "name": "Invalid Item",
            "price": "not_a_number"
        }
        response = client.post("/items", json=invalid_data)
        assert response.status_code == 422

    def test_create_item_with_optional_fields(self, client):
        """Test creating item with only required fields"""
        minimal_data = {
            "name": "Minimal Item",
            "price": 10.00
        }
        response = client.post("/items", json=minimal_data)
        assert response.status_code == 201
        data = response.json()
        assert data["in_stock"] is True  # Default value
        assert data["description"] is None  # Optional field
