package db

import (
	"database/sql"

	_ "github.com/lib/pq"
)

// DB 是全局数据库连接池变量，程序其他模块可以通过 `db.DB` 使用该连接池执行 SQL 操作
// 注意：使用前需要调用 `Init` 初始化连接池并校验连接。
var DB *sql.DB

// Init 初始化 PostgreSQL 连接池并验证可用性
//
// 参数:
//
//	dsn: Data Source Name，PostgreSQL 数据源名称，格式示例：
//	  "user=youruser password=yourpassword dbname=yourdb sslmode=disable"
//
// 返回值:
//
//	error: 初始化或连接验证失败时返回具体错误，成功返回 nil。
//
// 行为说明:
//   - 使用 `sql.Open` 打开一个数据库句柄（不会立即创建到数据库的连接），
//     只有在第一次使用连接或调用 `DB.Ping()` 时才会建立实际连接。
//   - 通过 `SetMaxOpenConns` 和 `SetMaxIdleConns` 设置连接池大小以控制并发连接数和空闲连接数，
//     根据服务负载和数据库性能可调整这两个参数。
//   - 调用 `DB.Ping()` 主动验证数据库连接是否可用，便于在启动阶段发现配置或网络问题。
//
// 使用示例:
//
//	err := db.Init("user=youruser password=yourpassword dbname=yourdb sslmode=disable")
//	if err != nil {
//	    // 处理错误（例如记录并退出程序）
//	}
func Init(dsn string) error {
	var err error
	DB, err = sql.Open("postgres", dsn)
	if err != nil {
		return err
	}

	// 限制最大打开连接数，避免数据库因过多连接而压垮
	DB.SetMaxOpenConns(10)

	// 限制最大空闲连接数，控制资源占用并保持一定的复用率
	DB.SetMaxIdleConns(5)

	// 主动 Ping 数据库以确认连接可用
	return DB.Ping()
}
