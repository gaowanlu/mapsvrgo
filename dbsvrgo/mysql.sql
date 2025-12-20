CREATE TABLE userrecord (
  id   BIGINT PRIMARY KEY,
  userId VARCHAR(64),
  password VARCHAR(64),
  baseInfo BLOB
);
