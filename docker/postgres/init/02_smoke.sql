-- 阶段 0 验收用的连通性检查表，不承载业务语义
CREATE TABLE IF NOT EXISTS smoke_test (
    id          BIGSERIAL PRIMARY KEY,
    note        TEXT NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT now()
);
