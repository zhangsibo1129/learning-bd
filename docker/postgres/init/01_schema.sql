-- 阶段 0 / 阶段 1 基础业务表
-- 场景：制造企业设备管理平台

CREATE TABLE IF NOT EXISTS factory (
    id          VARCHAR(64) PRIMARY KEY,
    name        VARCHAR(128) NOT NULL,
    location    VARCHAR(128),
    created_at  TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS equipment (
    id          VARCHAR(64) PRIMARY KEY,
    name        VARCHAR(128) NOT NULL,
    model       VARCHAR(64),
    factory_id  VARCHAR(64) REFERENCES factory (id),
    status      VARCHAR(32) NOT NULL DEFAULT 'RUNNING',
    created_at  TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS work_order (
    id            VARCHAR(64) PRIMARY KEY,
    equipment_id  VARCHAR(64) REFERENCES equipment (id),
    status        VARCHAR(32) NOT NULL DEFAULT 'OPEN',
    priority      VARCHAR(16) NOT NULL DEFAULT 'MEDIUM',
    created_at    TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_equipment_factory ON equipment (factory_id);
CREATE INDEX IF NOT EXISTS idx_equipment_status ON equipment (status);
CREATE INDEX IF NOT EXISTS idx_work_order_equipment ON work_order (equipment_id);
CREATE INDEX IF NOT EXISTS idx_work_order_status ON work_order (status);
