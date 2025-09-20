-- Ecommerce Database Schema
DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db
  CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;
USE ecommerce_db;
-- -----------------------------------------------------------
-- Table: customers
-- -----------------------------------------------------------

CREATE TABLE customers (
  customer_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(255) NOT NULL,
  phone VARCHAR(30),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (customer_id),
  UNIQUE KEY uq_customers_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------
-- Table: customer_profiles
-- One-to-One: customer -> customer_profile
-- -----------------------------------------------------------

CREATE TABLE customer_profiles (
  customer_id BIGINT UNSIGNED NOT NULL,
  birth_date DATE,
  gender ENUM('male','female','other') DEFAULT NULL,
  loyalty_points INT UNSIGNED NOT NULL DEFAULT 0,
  newsletter_subscribed TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (customer_id),
  CONSTRAINT fk_profile_customer
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------
-- Table: addresses
-- One-to-Many: customer -> addresses
-- -----------------------------------------------------------
CREATE TABLE addresses (
  address_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  customer_id BIGINT UNSIGNED NOT NULL,
  label VARCHAR(50) NULL, -- e.g., "Home", "Work"
  line1 VARCHAR(255) NOT NULL,
  line2 VARCHAR(255),
  city VARCHAR(100) NOT NULL,
  state_province VARCHAR(100),
  postal_code VARCHAR(20),
  country VARCHAR(100) NOT NULL,
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (address_id),
  INDEX idx_addresses_customer (customer_id),
  CONSTRAINT fk_addresses_customer
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------
-- Table: categories
-- Product categories (hierarchical via parent_category_id)
-- -----------------------------------------------------------
CREATE TABLE categories (
  category_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(120) NOT NULL,
  slug VARCHAR(140) NOT NULL,
  parent_category_id INT UNSIGNED NULL,
  description TEXT,
  PRIMARY KEY (category_id),
  UNIQUE KEY uq_categories_slug (slug),
  CONSTRAINT fk_categories_parent
    FOREIGN KEY (parent_category_id) REFERENCES categories(category_id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------
-- Table: products
-- -----------------------------------------------------------
CREATE TABLE products (
  product_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  sku VARCHAR(64) NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  weight_kg DECIMAL(6,3) DEFAULT NULL,
  category_id INT UNSIGNED NULL,
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (product_id),
  UNIQUE KEY uq_products_sku (sku),
  INDEX idx_products_category (category_id),
  CONSTRAINT fk_products_category
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------
-- Table: product_inventory
-- Tracks stock per product (one-to-one with product)
-- -----------------------------------------------------------
CREATE TABLE product_inventory (
  product_id BIGINT UNSIGNED NOT NULL,
  quantity_in_stock INT UNSIGNED NOT NULL DEFAULT 0,
  reserved INT UNSIGNED NOT NULL DEFAULT 0, -- reserved for pending orders
  last_restocked DATETIME,
  PRIMARY KEY (product_id),
  CONSTRAINT fk_inventory_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------
-- Table: suppliers
-- -----------------------------------------------------------
CREATE TABLE suppliers (
  supplier_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(200) NOT NULL,
  contact_email VARCHAR(255),
  phone VARCHAR(30),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (supplier_id),
  UNIQUE KEY uq_suppliers_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------
-- Many-to-Many: product_suppliers (a product can have many suppliers,
-- a supplier supplies many products)
-- -----------------------------------------------------------
CREATE TABLE product_suppliers (
  product_id BIGINT UNSIGNED NOT NULL,
  supplier_id INT UNSIGNED NOT NULL,
  supplier_sku VARCHAR(64),
  lead_time_days INT UNSIGNED DEFAULT NULL,
  cost_price DECIMAL(10,2) DEFAULT NULL,
  PRIMARY KEY (product_id, supplier_id),
  INDEX idx_ps_supplier (supplier_id),
  CONSTRAINT fk_ps_product FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_ps_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------
-- Table: orders
-- One-to-Many: customer -> orders
-- -----------------------------------------------------------
CREATE TABLE orders (
  order_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_number VARCHAR(50) NOT NULL, -- e.g., ORD-20250920-0001
  customer_id BIGINT UNSIGNED NOT NULL,
  billing_address_id BIGINT UNSIGNED NULL,
  shipping_address_id BIGINT UNSIGNED NULL,
  status ENUM('pending','paid','processing','shipped','delivered','cancelled','refunded') NOT NULL DEFAULT 'pending',
  subtotal DECIMAL(12,2) NOT NULL,
  shipping DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  tax DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  total DECIMAL(12,2) NOT NULL,
  placed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (order_id),
  UNIQUE KEY uq_orders_order_number (order_number),
  INDEX idx_orders_customer (customer_id),
  CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT fk_orders_billing_address
    FOREIGN KEY (billing_address_id) REFERENCES addresses(address_id)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  CONSTRAINT fk_orders_shipping_address
    FOREIGN KEY (shipping_address_id) REFERENCES addresses(address_id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------
-- Table: order_items
-- Many-to-Many between orders and products with additional fields
-- -----------------------------------------------------------
CREATE TABLE order_items (
  order_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  sku_at_purchase VARCHAR(64) NOT NULL,
  product_name_at_purchase VARCHAR(255) NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  quantity INT UNSIGNED NOT NULL,
  line_total DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (order_id, product_id),
  INDEX idx_order_items_product (product_id),
  CONSTRAINT fk_oi_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_oi_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------
-- Table: payments
-- One-to-One-ish relationship with orders (an order may have multiple payment attempts)
-- -----------------------------------------------------------
CREATE TABLE payments (
  payment_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id BIGINT UNSIGNED NOT NULL,
  payment_provider ENUM('stripe','paypal','mpesa','manual') NOT NULL,
  provider_transaction_id VARCHAR(255),
  amount DECIMAL(12,2) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  status ENUM('initiated','succeeded','failed','refunded') NOT NULL DEFAULT 'initiated',
  processed_at DATETIME,
  PRIMARY KEY (payment_id),
  INDEX idx_payments_order (order_id),
  CONSTRAINT fk_payments_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------
-- Table: product_reviews
-- Many-to-Many: customers review products (one customer can review many products)
-- -----------------------------------------------------------
CREATE TABLE product_reviews (
  review_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id BIGINT UNSIGNED NOT NULL,
  customer_id BIGINT UNSIGNED NOT NULL,
  rating TINYINT UNSIGNED NOT NULL CHECK (rating BETWEEN 1 AND 5),
  title VARCHAR(200),
  body TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (review_id),
  INDEX idx_reviews_product (product_id),
  INDEX idx_reviews_customer (customer_id),
  CONSTRAINT fk_reviews_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_reviews_customer
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------
-- Table: product_images
-- -----------------------------------------------------------
CREATE TABLE product_images (
  image_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id BIGINT UNSIGNED NOT NULL,
  url VARCHAR(1000) NOT NULL,
  alt_text VARCHAR(255),
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (image_id),
  INDEX idx_images_product (product_id),
  CONSTRAINT fk_images_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------
-- Helpful indexes for common queries
-- -----------------------------------------------------------
CREATE INDEX idx_products_name ON products (name(100));
CREATE INDEX idx_orders_placed_at ON orders (placed_at);
CREATE INDEX idx_customers_created_at ON customers (created_at);

-- -----------------------------------------------------------
-- Trigger: trg_inventory_before_update
-- Ensures quantity_in_stock >= reserved
-- -----------------------------------------------------------
DELIMITER $$
CREATE TRIGGER trg_inventory_before_update
BEFORE UPDATE ON product_inventory
FOR EACH ROW
BEGIN
  IF NEW.quantity_in_stock < NEW.reserved THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'quantity_in_stock cannot be less than reserved';
  END IF;
END$$
DELIMITER ;

-- End of Ecommerce Database Schema