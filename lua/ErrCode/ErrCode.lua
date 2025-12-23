---@class ErrCode table<string,number>
local ErrCode = {
    ERR_UNKNOW = -1,
    OK = 0,

    ERR_TARGET_MAP_NOT_FOUND = 1,
    ERR_USERID_INPUT_INVALID = 2,   -- UserID不合法
    ERR_PASSWORD_INPUT_INVALID = 3, -- Password不合法
};

return ErrCode;
