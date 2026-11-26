-- 实验用数据集：2 万客户 + 20 万订单
-- 用法：./scripts/psql.sh -f /sql/seed.sql

DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    id          BIGSERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    city        TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE orders (
    id           BIGSERIAL PRIMARY KEY,
    customer_id  BIGINT NOT NULL REFERENCES customers (id),
    amount       NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    status       TEXT NOT NULL DEFAULT 'paid',
    created_at   TIMESTAMPTZ NOT NULL
);

INSERT INTO customers (name, city)
SELECT
    'customer-' || i,
    (ARRAY['上海', '北京', '深圳', '成都', '杭州'])[1 + (i % 5)]
FROM generate_series(1, 20000) AS i;

INSERT INTO orders (customer_id, amount, status, created_at)
SELECT
    1 + (random() * 19999)::INT,
    round((random() * 990 + 10)::numeric, 2),
    (ARRAY['paid', 'refunded', 'pending'])[1 + floor(random() * 3)::INT],
    now() - (random() * interval '90 days')
FROM generate_series(1, 200000);

ANALYZE customers;
ANALYZE orders;

SELECT 'customers' AS table_name, count(*) FROM customers
UNION ALL
SELECT 'orders', count(*) FROM orders;
