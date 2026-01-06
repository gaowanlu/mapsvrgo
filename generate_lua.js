const fs = require('fs');
const path = require('path');

const PREFIX = `ProtoLua_`;

/**
 * proto 字段类型转lua类型
 * @param {string} protoType proto字段类型
 * @returns lua类型
 */
function protoToLuaType(protoType) {
  const typeMap = {
    int32: "integer",
    int64: "integer",
    uint32: "integer",
    uint64: "integer",
    sint32: "integer",
    sint64: "integer",
    fixed32: "integer",
    fixed64: "integer",
    sfixed32: "integer",
    sfixed64: "integer",
    float: "number",
    double: "number",
    bool: "boolean",
    string: "string",
    bytes: "string",
  };

  // 普通类型
  if (typeMap[protoType]) {
    return typeMap[protoType];
  }

  // 自定义Message类型
  return `${PREFIX}${protoType}`;
}

/**
 * 处理proto文件内容解析
 * @param {string} protoContent proto文件文本内容
 * @returns 返回解析出的内容
 */
function parseProto(protoContent) {
  const messages = {};
  const enums = {};

  let currentMessage = null;
  let currentEnum = null;
  let currentOneof = null;

  let pendingMessage = null;
  let pendingEnum = null;

  // 按行分割文件文本内容
  const lines = protoContent.split('\n');

  // 处理按行解析
  lines.forEach(rawLine => {
    // 去掉行开头与末尾的空格
    const line = rawLine.trim();
    // 空行或者为注释行则跳过
    if (!line || line === "" || line.startsWith('//')) return;

    // 如果行开头是某些特殊的关键词则跳过处理行
    if (
      line.startsWith('syntax') ||
      line.startsWith('package') ||
      line.startsWith('option')
    ) {
      return;
    }

    // 提取自定义message
    // 提取行开头为 ^message 
    // \s 匹配任何空白字符（如空格、制表符、换行符） + 匹配1个或多个
    // (\w+) 匹配一个字符、数字或者下划线等价于[a-zA-Z0-9_] +表示1个或多个空白字符 ()表示一个捕获组这部分内容会被提取出来，作为匹配结果的一部分返回
    const msgMatch = line.match(/^message\s+(\w+)/);
    if (msgMatch) {
      pendingMessage = msgMatch[1]; // mesgMatch[0]为全匹配 msgMatch[1]为()捕获部分
      console.debug(`pendingMessage: ${pendingMessage}`);
      return;
    }

    // 提取自定义enum 与 message方法相同
    const enumMatch = line.match(/^enum\s+(\w+)/);
    if (enumMatch) {
      pendingEnum = enumMatch[1];
      console.debug(`pendingEnum: ${pendingEnum}`);
      return;
    }

    // 协议开头{的那行
    if (line === '{') {
      // 正在处理 message内的oneof代码块
      if (currentOneof) {
        return;
      }

      // 这是个message
      if (pendingMessage) {
        // 将但当前正在处理的message状态进行切换
        currentMessage = pendingMessage;
        messages[currentMessage] = [];
        pendingMessage = null;
        return;
      }

      // 这是个enum
      if (pendingEnum) {
        // 将但当前正在处理的enum状态进行切换
        currentEnum = pendingEnum;
        enums[currentEnum] = [];
        pendingEnum = null;
        return;
      }
    }

    // 目前正在处理的是enum 按照枚举字段处理
    if (currentEnum) {
      // like
      // ENUM_ITEM=1;
      // ENUM_ITEM =1;
      // ENUM_ITEM = 1 ;
      const enumItem = line.match(/^(\w+)\s*=\s*(\d+)\s*;/);
      if (enumItem) {
        enums[currentEnum].push({
          name: enumItem[1],
          value: enumItem[2],
        });
        return;
      }
    }

    // 处理开头 如 oneof my_field的行
    const oneofMatch = line.match(/^oneof\s+(\w+)/);
    if (oneofMatch && currentMessage) {
      currentOneof = oneofMatch[1];
      return;
    }

    // 目前正在处理 message内的oneof 字段代码块
    if (currentOneof && currentMessage) {
      // oneof代码块内的字段
      const oneofField = line.match(/^(\w+)\s+(\w+)\s*=\s*\d+;/);
      if (oneofField) {
        messages[currentMessage].push({
          fieldName: oneofField[2], // 字段名
          luaType: protoToLuaType(oneofField[1]), // 字段对应lua类型
          oneof: currentOneof, // 是否是message内的oneof字段
        });
        return;
      }
    }

    // message内的repeated字段
    const repeatedMatch = line.match(
      /^repeated\s+(\w+)\s+(\w+)\s*=\s*\d+/
    );
    if (repeatedMatch && currentMessage) {
      const fieldType = repeatedMatch[1];
      const fieldName = repeatedMatch[2];
      const luaType = protoToLuaType(fieldType);

      messages[currentMessage].push({
        fieldName,
        luaType: `table<integer,${luaType}>`, // repeated字段按lua数组处理
        repeated: true,
      });

      return;
    }

    // message内普通字段
    if (!currentOneof && currentMessage) {
      const fieldMatch = line.match(/^(\w+)\s+(\w+)\s*=\s*\d+/);

      if (fieldMatch) {
        messages[currentMessage].push({
          fieldName: fieldMatch[2],
          luaType: protoToLuaType(fieldMatch[1]),
        });

        return;
      }
    }

    // 代码块结尾
    if (line === '}') {
      // oneof肯定在 message代码块外优先关闭代码块
      if (currentOneof) {
        currentOneof = null;
      } else if (currentEnum) {
        currentEnum = null;
      } else if (currentMessage) {
        currentMessage = null;
      }
    }
  });

  return { messages, enums };
}

/**
 * 生成EmmyLua类型约束注释
 * @param {*} messages parseProto 解析生成的 messages
 * @param {*} enums parseProto 解析生成的 enums
 * @returns lua文件文本内容
 */
function generateLuaClasses(messages, enums) {
  let out = '';

  // 处理每个枚举类型
  for (const [name, values] of Object.entries(enums)) {
    out += `---@alias ${PREFIX}${name} table<string,integer>\n`;
    out += `${PREFIX}${name} = {\n`;
    values.forEach(v => {
      out += `  ${v.name} = ${v.value},\n`;
    });
    out += `}\n\n`;
  }

  // message类型
  for (const [msg, fields] of Object.entries(messages)) {
    out += `---@class ${PREFIX}${msg}\n`;
    fields.forEach(f => {
      // oneof字段
      if (f.oneof) {
        out += `---@field ${f.fieldName} ${f.luaType}|nil -- oneof ${f.oneof}\n`;
      } else { // 非oneof字段
        out += `---@field ${f.fieldName} ${f.luaType}\n`;
      }
    });
    out += `\n`;
  }

  return out;
}

/**
 * 处理单个 proto 文件
 * @param {*} protoFile 要处理的文件路径
 * @param {*} outDir 输出路径
 */
function processProtoFile(protoFile, outDir) {
  // 同步读出输入文件全部文本内容
  const protoContent = fs.readFileSync(protoFile, 'utf8');
  // 解析proto文件内容
  const { messages, enums } = parseProto(protoContent);
  // 生成lua文件内容
  const luaCode = generateLuaClasses(messages, enums);

  // 获取文件名且去掉扩展名
  const baseName = path.basename(protoFile, '.proto');
  // 拼接输出文件路径和.lua文件名称
  const outFile = path.join(outDir, `${baseName}.lua`);
  // 同步写目标lua文件
  fs.writeFileSync(outFile, luaCode);

  console.log(`生成: ${outFile}`);
}

// node generate_lua.js <proto文件或目录> <输出目录>
function main() {
  // node generate_lua.js inputPath outDir
  let [, , inputPath, outDir] = process.argv;

  // 默认使用 inputPath=./protocol/ outDir=./lua/ProtoLua/
  if (!inputPath || !outDir) {
    inputPath = './protocol/';
    outDir = './lua/ProtoLua/';
    console.warn(`using default inputPath=./protocol/ outDir=./lua/ProtoLua/`);
  }

  // 这里inputPath或outDir仍没指定肯定有问题
  if (!inputPath || !outDir) {
    console.error('用法: node generate_lua.js <proto文件或目录> <输出目录>');
    process.exit(1);
  }

  if (!fs.existsSync(inputPath)) {
    console.error('找不到输入路径:', inputPath);
    process.exit(1);
  }

  // 检查输出目标目录是否存在不存在则创建
  if (!fs.existsSync(outDir)) {
    try {
      fs.mkdirSync(outDir, { recursive: true });
    } catch (err) {
      console.error(`创建目录失败 ${err}`);
      process.exit(1);
    }
  }

  // 读取inputPath类型 可能是目录也可能是文件
  const stat = fs.statSync(inputPath);

  // 单个proto文件
  if (stat.isFile()) {
    if (!inputPath.endsWith('.proto')) {
      console.error(`输入文件不是 .proto: ${inputPath}`);
      process.exit(1);
    }

    // 只处理单个proto文件
    processProtoFile(inputPath, outDir);
    return;

  }
  else if (stat.isDirectory()) {  // 处理输入文件夹下的proto文件

    // 读取文件夹
    const files = fs.readdirSync(inputPath);

    files.forEach(file => {
      // 只处理文件夹下的proto文件
      if (!file.endsWith('.proto')) return;

      // 拼接路径
      const fullPath = path.join(inputPath, file);

      // 处理单个文件
      processProtoFile(fullPath, outDir);
    });

    console.log('处理完成');
    return;
  }
  else {
    console.error('输入路径既不是文件也不是目录:', inputPath);
    process.exit(1);
  }
}

main();
