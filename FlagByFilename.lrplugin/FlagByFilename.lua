local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrLogger = import 'LrLogger'

-- ---------- Logger ----------
local logger = LrLogger('FlagByFilename')
logger:enable("logfile") -- 写入 Plugin.log

-- ---------- Utils ----------
local function normalizeFilename(name)
    if not name then return "" end
    name = string.lower(name)
    name = string.gsub(name, "^%s+", ""):gsub("%s+$", "") -- 去首尾空格
    name = string.gsub(name, "%.[^.]+$", "") -- 去扩展名
    return name
end

-- ---------- Main ----------
LrTasks.startAsyncTask(function()

    LrFunctionContext.callWithContext("FlagByFilename", function(context)

        logger:info("===== 插件启动 =====")

        local f = LrView.osFactory()
        local props = LrBinding.makePropertyTable(context)

        props.filenameList = ""

        -- ---------- UI ----------
        local c = f:column{
            spacing = f:control_spacing(),
            width = 500, -- 窗口最小宽度
            fill_horizontal = 1, -- 横向填充
            f:static_text{
                title = "请输入要标记的文件名（每行一个，忽略扩展名和大小写）：",
                alignment = 'left',
                word_wrap = true
            },
            f:row{
                fill_horizontal = 1,
                f:edit_field{
                    value = LrView.bind {key = 'filenameList', object = props},
                    width_in_chars = 50,
                    height_in_lines = 15,
                    allows_multiline = true,
                    immediate = true,
                    fill_horizontal = 1, -- 横向自适应
                    fill_vertical = 1 -- 纵向自适应
                }
            }
        }

        local result = LrDialogs.presentModalDialog {
            title = "根据文件名设置旗标",
            contents = c,
            bindToObject = props,
            actionVerb = "开始标记"
        }

        if result ~= 'ok' then
            logger:info("对话框已取消")
            return
        end

        logger:info("输入文本长度: " ..
                        tostring(string.len(props.filenameList)))

        -- ---------- 解析输入 ----------
        local nameSet = {}
        local lineCount = 0

        for line in props.filenameList:gmatch("[^\r\n]+") do
            lineCount = lineCount + 1
            local n = normalizeFilename(line)
            if n ~= "" then nameSet[n] = true end
        end

        logger:info("输入行数: " .. tostring(lineCount))

        if next(nameSet) == nil then
            LrDialogs.message("警告", "没有输入任何有效文件名")
            logger:info("没有有效文件名，终止操作")
            return
        end

        -- ---------- Catalog ----------
        local catalog = LrApplication.activeCatalog()

        catalog:withWriteAccessDo("根据文件名设置旗标", function()

            local photos = catalog:getTargetPhotos()
            local filtered = {}

            for _, p in ipairs(photos) do
                if p:type() == 'LrPhoto' then
                    table.insert(filtered, p)
                end
            end

            photos = filtered
            logger:info("目标照片数量: " .. tostring(#photos))

            local hit = 0

            for _, photo in ipairs(photos) do
                local path = photo:getRawMetadata('path')
                if path then
                    local filename = path:match("([^/\\]+)$")
                    local key = normalizeFilename(filename)

                    if nameSet[key] then
                        photo:setRawMetadata('pickStatus', 1)
                        hit = hit + 1
                        logger:info("匹配成功: " .. key)
                    end
                end
            end

            logger:info("总匹配数量: " .. tostring(hit))
            LrDialogs.message("完成",
                              string.format("已标记 %d 张照片", hit))
        end)

        logger:info("===== 插件结束 =====")
    end)
end)
