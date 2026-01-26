CREATE DATABASE IF NOT EXISTS dbname;
use dbname;

CREATE TABLE IF NOT EXISTS db_user_record (
  id   BIGINT PRIMARY KEY COMMENT '记录唯一ID由时间戳生成',
  user_id VARCHAR(64) NOT NULL COMMENT '用户ID',
  password VARCHAR(64) NOT NULL COMMENT '用户密码',
  base_info BLOB COMMENT 'protobuf数据序列化后的数据'
) Engine=InnoDB CHARSET=utf8 COMMENT '用户记录数据表';

ALTER TABLE db_user_record
ADD UNIQUE KEY uk_user_id (user_id);

#docker pull mysql:9.5.0
#docker run --name some-mysql -p 127.0.0.1:3306:3306 -e MYSQL_ROOT_PASSWORD=root -d mysql:9.5.0
#docker exec -it some-mysql bash
#mysql -uroot -p
#docker stop some-mysql
#docker rm some-mysql
