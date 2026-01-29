CREATE DATABASE koyebdb;
\c koyebdb

-- 创建表，如果不存在的话
CREATE TABLE IF NOT EXISTS db_user_record (
  id BIGINT PRIMARY KEY,  -- 记录唯一ID，直接使用 BIGINT
  user_id VARCHAR(64) NOT NULL,  -- 用户ID
  password VARCHAR(64) NOT NULL,  -- 用户密码
  base_info BYTEA,  -- PostgreSQL 中使用 BYTEA 存储二进制数据（代替 BLOB）
  CONSTRAINT uk_user_id UNIQUE (user_id)  -- 添加唯一约束，代替 UNIQUE KEY
);

-- PostgreSQL 中不需要 ALTER TABLE 添加约束，因为可以在 CREATE TABLE 语句中直接定义
-- 如果要添加唯一约束（如果表已经存在），则可以使用下面的语句：
-- ALTER TABLE db_user_record
-- ADD CONSTRAINT uk_user_id UNIQUE (user_id);

# docker pull postgres:14.19-alpine3.21
# docker run --name some-postgres -p 127.0.0.1:5432:5432 -e POSTGRES_PASSWORD=root -d postgres:14.19-alpine3.21
# docker exec -it some-postgres bash
# psql -U postgres
# docker stop some-postgres
# docker rm some-postgres
