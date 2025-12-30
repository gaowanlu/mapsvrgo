const fs = require('fs');
const path = require('path');

const PREFIX = `ProtoLua_`;

/**
 * proto 基础类型 → Lua 类型
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
  return typeMap[protoType] || `${PREFIX}${protoType}`;
}

/**
 * 解析 proto
 * 支持：
 * - enum / message 与 { 分行
 * - oneof
 * - repeated
 */
function parseProto(protoContent) {
  const messages = {};
  const enums = {};

  let currentMessage = null;
  let currentEnum = null;
  let currentOneof = null;

  let pendingMessage = null;
  let pendingEnum = null;

  const lines = protoContent.split('\n');

  lines.forEach(rawLine => {
    const line = rawLine.trim();
    if (!line || line.startsWith('//')) return;

    if (
      line.startsWith('syntax') ||
      line.startsWith('package') ||
      line.startsWith('option')
    ) {
      return;
    }

    /** message name（不要求 {） */
    const msgMatch = line.match(/^message\s+(\w+)/);
    if (msgMatch) {
      pendingMessage = msgMatch[1];
      return;
    }

    /** enum name（不要求 {） */
    const enumMatch = line.match(/^enum\s+(\w+)/);
    if (enumMatch) {
      pendingEnum = enumMatch[1];
      return;
    }

    /** block start */
    if (line === '{') {
      if (pendingMessage) {
        currentMessage = pendingMessage;
        messages[currentMessage] = [];
        pendingMessage = null;
        return;
      }
      if (pendingEnum) {
        currentEnum = pendingEnum;
        enums[currentEnum] = [];
        pendingEnum = null;
        return;
      }
    }

    /** enum field */
    if (currentEnum) {
      const enumItem = line.match(/^(\w+)\s*=\s*(\d+)\s*;/);
      if (enumItem) {
        enums[currentEnum].push({
          name: enumItem[1],
          value: enumItem[2],
        });
        return;
      }
    }

    /** oneof */
    const oneofMatch = line.match(/^oneof\s+(\w+)/);
    if (oneofMatch && currentMessage) {
      currentOneof = oneofMatch[1];
      return;
    }

    /** oneof field */
    if (currentOneof && currentMessage) {
      const oneofField = line.match(/^(\w+)\s+(\w+)\s*=\s*\d+/);
      if (oneofField) {
        messages[currentMessage].push({
          fieldName: oneofField[2],
          luaType: protoToLuaType(oneofField[1]),
          oneof: currentOneof,
        });
        return;
      }
    }

    /** repeated field */
    const repeatedMatch = line.match(
      /^repeated\s+(\w+)\s+(\w+)\s*=\s*\d+/
    );
    if (repeatedMatch && currentMessage) {
      const fieldType = repeatedMatch[1];
      const fieldName = repeatedMatch[2];
      const luaType = protoToLuaType(fieldType);

      messages[currentMessage].push({
        fieldName,
        luaType: `table<integer,${luaType}>`,
        repeated: true,
      });
      return;
    }

    /** normal field */
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

    /** block end */
    if (line === '}') {
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
 * 生成 Lua + EmmyLua
 */
function generateLuaClasses(messages, enums) {
  let out = '';

  /** enum */
  for (const [name, values] of Object.entries(enums)) {
    out += `---@alias ${PREFIX}${name} integer\n`;
    out += `${PREFIX}${name} = {\n`;
    values.forEach(v => {
      out += `  ${v.name} = ${v.value},\n`;
    });
    out += `}\n\n`;
  }

  /** message */
  for (const [msg, fields] of Object.entries(messages)) {
    out += `---@class ${PREFIX}${msg}\n`;
    fields.forEach(f => {
      if (f.oneof) {
        out += `---@field ${f.fieldName} ${f.luaType}|nil -- oneof ${f.oneof}\n`;
      } else {
        out += `---@field ${f.fieldName} ${f.luaType}\n`;
      }
    });
    out += `\n`;
  }

  return out;
}

/* ===================== main ===================== */
function main() {
  let [, , inputPath, outDir] = process.argv;

  if (!inputPath || !outDir) {
    inputPath = './protocol/';
    outDir = './lua/ProtoLua/';
  }

  if (!inputPath || !outDir) {
    console.error('用法: node generate_lua.js <proto文件或目录> <输出目录>');
    process.exit(1);
  }

  if (!fs.existsSync(inputPath)) {
    console.error('找不到输入路径:', inputPath);
    process.exit(1);
  }

  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }

  const stat = fs.statSync(inputPath);

  /** ========= 单个 proto 文件 ========= */
  if (stat.isFile()) {
    if (!inputPath.endsWith('.proto')) {
      console.error('输入文件不是 .proto:', inputPath);
      process.exit(1);
    }

    processProtoFile(inputPath, outDir);
    return;
  }

  /** ========= proto 文件夹（不递归） ========= */
  if (stat.isDirectory()) {
    const files = fs.readdirSync(inputPath);

    files.forEach(file => {
      if (!file.endsWith('.proto')) return;

      const fullPath = path.join(inputPath, file);
      processProtoFile(fullPath, outDir);
    });

    console.log('处理完成');
    return;
  }

  console.error('输入路径既不是文件也不是目录:', inputPath);
}

/**
 * 处理单个 proto 文件
 */
function processProtoFile(protoFile, outDir) {
  const protoContent = fs.readFileSync(protoFile, 'utf8');
  const { messages, enums } = parseProto(protoContent);

  const luaCode = generateLuaClasses(messages, enums);
  const baseName = path.basename(protoFile, '.proto');
  const outFile = path.join(outDir, `${baseName}.lua`);

  fs.writeFileSync(outFile, luaCode);
  console.log('生成:', outFile);
}

main();
