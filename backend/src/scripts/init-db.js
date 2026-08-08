require("dotenv").config({ override: true });

const db = require("../config/db");

async function createSchema(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS users (
      id BIGSERIAL PRIMARY KEY,
      full_name VARCHAR(120) NOT NULL,
      pin_code VARCHAR(6) NOT NULL UNIQUE,
      role_id SMALLINT NOT NULL CHECK (role_id IN (1, 2)),
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await client.query(`
    ALTER TABLE users
    ALTER COLUMN pin_code TYPE VARCHAR(6);
  `);

  await client.query(`
    UPDATE users
    SET role_id = CASE
      WHEN role_id = 3 THEN 2
      ELSE 1
    END
    WHERE role_id IN (1, 2, 3);
  `);

  await client.query(`
    ALTER TABLE users
    DROP CONSTRAINT IF EXISTS users_role_id_check;
  `);

  await client.query(`
    ALTER TABLE users
    ADD CONSTRAINT users_role_id_check CHECK (role_id IN (1, 2));
  `);

  await client.query(`
    CREATE TABLE IF NOT EXISTS categories (
      id BIGSERIAL PRIMARY KEY,
      name VARCHAR(100) NOT NULL UNIQUE,
      image_path VARCHAR(255),
      printer_route VARCHAR(20) NOT NULL DEFAULT 'MUTFAK',
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      sort_order INT NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await client.query(`
    ALTER TABLE categories
    ADD COLUMN IF NOT EXISTS image_path VARCHAR(255);
  `);

  await client.query(`
    ALTER TABLE categories
    ADD COLUMN IF NOT EXISTS printer_route VARCHAR(20) NOT NULL DEFAULT 'MUTFAK';
  `);

  await client.query(`
    UPDATE categories
    SET printer_route = CASE
      WHEN UPPER(name) IN (
        'SICAK İÇECEKLER',
        'SOĞUK İÇECEKLER',
        'ÇAYLAR',
        'TÜRK KAHVESİ ÇEŞİTLERİ',
        'ESPRESSOLU KAHVELER',
        'FİLTRE KAHVELER',
        'FRAPPELER',
        'SAHLEP-SICAK ÇİKOLATA',
        'SOĞUK KAHVELER',
        'MEŞRUBATLAR',
        'MEYVELİ FROZENLER',
        'MİLKSHAKELER',
        'MATCHA (MAÇA)',
        'DETOKS'
      ) THEN 'BAR'
      ELSE COALESCE(NULLIF(UPPER(printer_route), ''), 'MUTFAK')
    END,
    updated_at = NOW()
    WHERE printer_route IS NULL
      OR TRIM(printer_route) = ''
      OR UPPER(printer_route) NOT IN ('MUTFAK', 'BAR', 'KASA');
  `);

  await client.query(`
    ALTER TABLE categories
    DROP CONSTRAINT IF EXISTS categories_printer_route_check;
  `);

  await client.query(`
    ALTER TABLE categories
    ADD CONSTRAINT categories_printer_route_check
    CHECK (printer_route IN ('MUTFAK', 'BAR', 'KASA'));
  `);

  await client.query(`
    CREATE TABLE IF NOT EXISTS products (
      id BIGSERIAL PRIMARY KEY,
      category_id BIGINT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
      category VARCHAR(100),
      name VARCHAR(140) NOT NULL,
      sku VARCHAR(60),
      price NUMERIC(12, 2) NOT NULL CHECK (price >= 0),
      vat_rate NUMERIC(5, 2) NOT NULL DEFAULT 10.00 CHECK (vat_rate >= 0),
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (category_id, name)
    );
  `);

  await client.query(`
    ALTER TABLE products
    ADD COLUMN IF NOT EXISTS category VARCHAR(100);
  `);

  await client.query(`
    UPDATE products p
    SET category = c.name,
        updated_at = NOW()
    FROM categories c
    WHERE c.id = p.category_id
      AND (p.category IS NULL OR p.category = '' OR p.category <> c.name);
  `);

  await client.query(`
    CREATE TABLE IF NOT EXISTS tables (
      id BIGSERIAL PRIMARY KEY,
      table_code VARCHAR(20) NOT NULL UNIQUE,
      display_name VARCHAR(80) NOT NULL,
      zone VARCHAR(60) NOT NULL DEFAULT 'Salon',
      capacity INT NOT NULL DEFAULT 4 CHECK (capacity > 0),
      is_custom BOOLEAN NOT NULL DEFAULT FALSE,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await client.query(`
    ALTER TABLE tables
    ADD COLUMN IF NOT EXISTS zone VARCHAR(60) NOT NULL DEFAULT 'Salon';
  `);

  await client.query(`
    ALTER TABLE tables
    ADD COLUMN IF NOT EXISTS is_custom BOOLEAN NOT NULL DEFAULT FALSE;
  `);

  await client.query(`
    CREATE TABLE IF NOT EXISTS orders (
      id BIGSERIAL PRIMARY KEY,
      table_id BIGINT NOT NULL REFERENCES tables(id) ON DELETE RESTRICT,
      waiter_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
      opened_by_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
      closed_by_user_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
      payment_method VARCHAR(20)
        CHECK (payment_method IN ('CASH', 'CARD', 'MIXED', 'OTHER')),
      order_status VARCHAR(20) NOT NULL DEFAULT 'OPEN'
        CHECK (order_status IN ('OPEN', 'CONFIRMED', 'PAID', 'CANCELLED')),
      note TEXT,
      guest_count INT NOT NULL DEFAULT 1 CHECK (guest_count > 0),
      table_note TEXT,
      subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
      discount_total NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (discount_total >= 0),
      grand_total NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (grand_total >= 0),
      opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      confirmed_at TIMESTAMPTZ,
      closed_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await client.query(`
    ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS payment_method VARCHAR(20)
      CHECK (payment_method IN ('CASH', 'CARD', 'MIXED', 'OTHER'));
  `);

  await client.query(`
    ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS opened_by_user_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
    ADD COLUMN IF NOT EXISTS closed_by_user_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
    ADD COLUMN IF NOT EXISTS note TEXT,
    ADD COLUMN IF NOT EXISTS guest_count INT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS table_note TEXT;
  `);

  await client.query(`
    ALTER TABLE orders
    DROP CONSTRAINT IF EXISTS orders_guest_count_check;
  `);

  await client.query(`
    ALTER TABLE orders
    ADD CONSTRAINT orders_guest_count_check CHECK (guest_count > 0);
  `);

  await client.query(`
    CREATE TABLE IF NOT EXISTS order_items (
      id BIGSERIAL PRIMARY KEY,
      order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
      product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      category_snapshot VARCHAR(100),
      printer_route_snapshot VARCHAR(20) NOT NULL DEFAULT 'MUTFAK',
      product_name_snapshot VARCHAR(140) NOT NULL,
      unit_price_snapshot NUMERIC(12, 2) NOT NULL CHECK (unit_price_snapshot >= 0),
      quantity NUMERIC(10, 2) NOT NULL CHECK (quantity > 0),
      line_total NUMERIC(12, 2) NOT NULL CHECK (line_total >= 0),
      item_status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (item_status IN ('PENDING', 'SENT', 'PAID', 'VOID')),
      note TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await client.query(`
    ALTER TABLE order_items
    ADD COLUMN IF NOT EXISTS note TEXT;
  `);

  await client.query(`
    ALTER TABLE order_items
    ADD COLUMN IF NOT EXISTS category_snapshot VARCHAR(100);
  `);

  await client.query(`
    ALTER TABLE order_items
    ADD COLUMN IF NOT EXISTS printer_route_snapshot VARCHAR(20) NOT NULL DEFAULT 'MUTFAK';
  `);

  await client.query(`
    UPDATE order_items oi
    SET
      category_snapshot = COALESCE(NULLIF(p.category, ''), c.name),
      printer_route_snapshot = COALESCE(NULLIF(c.printer_route, ''), 'MUTFAK')
    FROM products p
    JOIN categories c ON c.id = p.category_id
    WHERE p.id = oi.product_id
      AND (
        oi.category_snapshot IS NULL
        OR oi.category_snapshot = ''
        OR oi.printer_route_snapshot IS NULL
        OR oi.printer_route_snapshot = ''
        OR oi.printer_route_snapshot NOT IN ('MUTFAK', 'BAR', 'KASA')
      );
  `);

  await client.query(`
    ALTER TABLE order_items
    DROP CONSTRAINT IF EXISTS order_items_printer_route_snapshot_check;
  `);

  await client.query(`
    ALTER TABLE order_items
    ADD CONSTRAINT order_items_printer_route_snapshot_check
    CHECK (printer_route_snapshot IN ('MUTFAK', 'BAR', 'KASA'));
  `);

  await client.query(`
    CREATE TABLE IF NOT EXISTS payments (
      id BIGSERIAL PRIMARY KEY,
      order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
      received_by_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
      payment_method VARCHAR(20) NOT NULL
        CHECK (payment_method IN ('CASH', 'CARD', 'MEAL_CARD', 'MIXED', 'OTHER')),
      amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
      discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
      currency VARCHAR(3) NOT NULL DEFAULT 'TRY',
      meal_card_type VARCHAR(100),
      payment_note TEXT,
      paid_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await client.query(`
    ALTER TABLE payments
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
  `);

  await client.query(`
    ALTER TABLE payments
    ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0);
  `);

  await client.query(`
    ALTER TABLE payments
    ADD COLUMN IF NOT EXISTS meal_card_type VARCHAR(100);
  `);

  await client.query(`
    CREATE TABLE IF NOT EXISTS voids (
      id BIGSERIAL PRIMARY KEY,
      order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
      order_item_id BIGINT REFERENCES order_items(id) ON DELETE SET NULL,
      product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      action_type VARCHAR(20) NOT NULL CHECK (action_type IN ('VOID', 'COMP')),
      quantity NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (quantity >= 0),
      reason TEXT,
      created_by_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await client.query(`
    CREATE TABLE IF NOT EXISTS z_reports (
      id BIGSERIAL PRIMARY KEY,
      report_date DATE NOT NULL UNIQUE,
      total_revenue NUMERIC(12, 2) NOT NULL DEFAULT 0,
      cash_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
      card_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
      total_orders INT NOT NULL DEFAULT 0,
      total_subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0,
      total_vat NUMERIC(12, 2) NOT NULL DEFAULT 0,
      generated_by_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
      payload JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await client.query(`
    CREATE TABLE IF NOT EXISTS expenses (
      id BIGSERIAL PRIMARY KEY,
      expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
      item_name VARCHAR(160) NOT NULL,
      quantity NUMERIC(10, 2) NOT NULL CHECK (quantity > 0),
      unit_price NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
      total_amount NUMERIC(12, 2) NOT NULL CHECK (total_amount >= 0),
      note TEXT,
      created_by_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await client.query(`
    CREATE INDEX IF NOT EXISTS idx_orders_table_id ON orders(table_id);
    CREATE INDEX IF NOT EXISTS idx_orders_waiter_id ON orders(waiter_id);
    CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(order_status);
    CREATE INDEX IF NOT EXISTS idx_orders_closed_at ON orders(closed_at);
    CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
    CREATE INDEX IF NOT EXISTS idx_order_items_status ON order_items(item_status);
    CREATE INDEX IF NOT EXISTS idx_order_items_category_snapshot ON order_items(category_snapshot);
    CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
    CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);
    CREATE INDEX IF NOT EXISTS idx_payments_paid_at ON payments(paid_at);
    CREATE INDEX IF NOT EXISTS idx_voids_order_id ON voids(order_id);
    CREATE INDEX IF NOT EXISTS idx_z_reports_report_date ON z_reports(report_date);
    CREATE INDEX IF NOT EXISTS idx_expenses_expense_date ON expenses(expense_date);
  `);
}

async function seedUsers(client) {
  await client.query(
    `
      UPDATE users
      SET pin_code = '122323', updated_at = NOW()
      WHERE pin_code = '672306';
    `
  );

  await client.query(
    `
      INSERT INTO users (full_name, pin_code, role_id, is_active)
      VALUES
        ('Garson Kullanıcı', '122323', 2, TRUE),
        ('Admin Kullanıcı', '062362', 1, TRUE)
      ON CONFLICT (pin_code)
      DO UPDATE SET
        full_name = EXCLUDED.full_name,
        role_id = EXCLUDED.role_id,
        is_active = EXCLUDED.is_active,
        updated_at = NOW();
    `
  );

  await client.query(
    `
      UPDATE users
      SET is_active = FALSE, updated_at = NOW()
      WHERE pin_code IN ('2222', '3333', '1111');
    `
  );
}

async function run() {
  const client = await db.pool.connect();

  try {
    await client.query("BEGIN");
    await createSchema(client);
    await seedUsers(client);
    await client.query("COMMIT");
    console.log("Database schema and seed completed successfully.");
    console.log("Seed users => Waiter:122323, Admin:062362");
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("init-db failed:", error);
    process.exitCode = 1;
  } finally {
    client.release();
    await db.pool.end();
  }
}

run();
