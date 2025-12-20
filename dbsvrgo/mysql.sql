CREATE DATABASE IF NOT EXISTS dbname;
use dbname;

CREATE TABLE IF NOT EXISTS dbuserrecord (
  id   BIGINT PRIMARY KEY,
  userId VARCHAR(64),
  password VARCHAR(64),
  baseInfo BLOB
);

#docker run --name some-mysql -p 127.0.0.1:3306:3306 -e MYSQL_ROOT_PASSWORD=root -d mysql:9.5.0
#docker exec -it some-mysql bash
#mysql -uroot -p
#docker stop some-mysql
#docker rm some-mysql
