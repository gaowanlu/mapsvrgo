CREATE DATABASE IF NOT EXISTS dbname;
use dbname;

CREATE TABLE IF NOT EXISTS dbuserrecord (
  id   BIGINT PRIMARY KEY COMMENT '记录唯一ID由时间戳生成',
  userId VARCHAR(64) NOT NULL COMMENT '用户ID',
  password VARCHAR(64) NOT NULL '用户密码',
  baseInfo BLOB COMMENT 'protobuf数据序列化后的数据'
) Engine=InnoDB CHARSET=utf8 COMMENT '用户记录数据表';

ALTER TABLE dbuserrecord
ADD UNIQUE KEY uk_userId (userId);

#docker pull mysql:9.5.0
#docker run --name some-mysql -p 127.0.0.1:3306:3306 -e MYSQL_ROOT_PASSWORD=root -d mysql:9.5.0
#docker exec -it some-mysql bash
#mysql -uroot -p
#docker stop some-mysql
#docker rm some-mysql
