---@class ErrCode table<string,integer>
local ErrCode = {
    ERR_UNKNOW = -1,
    OK = 0,

    ERR_TARGET_MAP_NOT_FOUND = 1,
    ERR_USERID_INPUT_INVALID = 2,        -- UserID不合法
    ERR_PASSWORD_INPUT_INVALID = 3,      -- Password不合法
    ERR_USERID_OR_PASSWORD_NOTMATCH = 4, -- UserID或PassWord不正确

    ERR_SERVICE_SAFESTOPED = 5,          -- 服务已关闭
};

return ErrCode;
