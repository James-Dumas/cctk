local util = {
    sum = function(...)
        local result = 0
        for i, v in ipairs(arg) do
            result = result + v
        end

        return result
    end,

    wrap_text = function(text, width)
        local lines = {}
        local line = ""
        local prev_space = ""
        for word, space in string.gmatch(text, "(%S*)(%s*)") do
            if #line + #word + 1 > width then
                table.insert(lines, line:sub(1, -prev_space:len() - 1))
                line = word .. space
            else
                line = line .. word .. space
            end

            prev_space = space
        end

        if #line > 0 then
            table.insert(lines, line:sub(1, -prev_space:len() - 1))
        end

        return lines
    end,
}

local colors = {
    white = "0",
    orange = "1",
    magenta = "2",
    light_blue = "3",
    yellow = "4",
    lime = "5",
    lime_green = "5",
    light_green = "5",
    pink = "6",
    light_red = "6",
    gray = "7",
    grey = "7",
    light_gray = "8",
    light_grey = "8",
    cyan = "9",
    purple = "a",
    blue = "b",
    brown = "c",
    green = "d",
    red = "e",
    black = "f",
}

local GUI = {
    render = {
        buf_back = {},
        buf_front = {},
    },
    resize = true,
    redraw = true,
    exit = false,
}

function GUI:init(widget)
    -- initialize GUI with given widget as root
    widget.fill_mode = "full"
    widget.visible = true
    if widget.bg_color == nil then
        widget.bg_color = colors.black
    end
    self.root = widget
    term.setCursorBlink(false)
    term.clear()
end

function GUI:main()
    -- GUI main loop

    if not self.root then
        return
    end

    -- define function for handling os events
    local function main1()
        while not self.exit do
            local event_data = {os.pullEventRaw()}
            if event_data[1] == "mouse_click" then
                local clicked_widget = self.root:get_widget_by_pos(event_data[3], event_data[4])
                if clicked_widget then
                    clicked_widget:handle_click(unpack(event_data, 2, 4))
                end
            elseif event_data[1] == "term_resize" then
                self.root:resize()
                self.redraw = true
            elseif event_data[1] == "terminate" then
                self.exit = true
            end

            self.root:handle_event(unpack(event_data))
        end
    end

    -- define function for processing widget updates
    local function main2()
        while not self.exit do
            self.root:handle_tick()

            if self.resize then
                self.resize = false
                self.redraw = true
                self.root:update_size_want()
                term_w, term_h = term.getSize()
                local screen_rect = {
                    x = 1,
                    y = 1,
                    w = term_w,
                    h = term_h,
                }
                self.root:update_rect(screen_rect)
            end

            if self.redraw then
                self.redraw = false
                self.root:draw()
                self.render:draw()
            end

            os.sleep(0.05)
        end
    end

    -- Enter main loop
    parallel.waitForAll(main1, main2)
    term.clear()
    term.setCursorPos(1, 1)
end

function GUI.render:draw()
    -- copy back buffer to front buffer and draw changed chars
    local width, height = term.getSize()
    local cursor_blink = term.getCursorBlink()
    local cursor_x, cursor_y = term.getCursorPos()
    term.setCursorBlink(false)
    for x = 1, width do
        for y = 1, height do
            local key = x .. "." .. y
            local back_char = self.buf_back[key]
            local front_char = self.buf_front[key]
            if back_char and (not front_char or back_char.char ~= front_char.char or back_char.fg ~= front_char.fg or back_char.bg ~= front_char.bg) then
                term.setCursorPos(x, y)
                term.blit(back_char.char, back_char.fg, back_char.bg)
                self.buf_front[key] = back_char
            end
        end
    end

    term.setCursorBlink(cursor_blink)
    term.setCursorPos(cursor_x, cursor_y)
end

function GUI.render:blit_char(char, x, y, fg, bg)
    -- draw a single char to the render buffer
    local key = x .. "." .. y
    self.buf_back[key] = {
        char = char,
        fg = fg or colors.white,
        bg = bg or colors.black,
    }
end

function GUI.render:blit_text(text, x, y, fg, bg)
    -- draw some text to the render buffer
    local h = 0
    local k = 0
    for i = 1, #text do
        local char = text:sub(i, i)
        if char == "\n" then
            k = k + 1
            h = 0
        else
            self:blit_char(char, x + h, y + k, fg, bg)
            h = h + 1
        end
    end
end

function GUI.render:blit_rect(x, y, w, h, bg)
    -- draw a rectangle to the render buffer
    for i = x, x + w - 1 do
        for j = y, y + h - 1 do
            self:blit_char(" ", i, j, bg, bg)
        end
    end
end

function GUI.render:clear()
    -- clear the render buffer and screen
    self.buf_back = {}
    self.buf_front = {}
    term.clear()
end

-- Base Widget class
local Widget = {
    visible = true,
    fill_mode = "none",
    h_align = "center",
    v_align = "center",
    fg_color = colors.white,
    bg_color = nil, -- inherit from parent
    event_handlers = {},
}
Widget.__index = Widget

function Widget:new()
    o = {}
    setmetatable(o, self)
    o.rect = {
        x = 0,
        y = 0,
        w = 0,
        h = 0
    }
    o.size_want = {
        w = 0,
        h = 0,
    }
    o.padding = {
        left = 0,
        right = 0,
        top = 0,
        bottom = 0
    }

    return o
end

function Widget:update_size_want()
    -- recalculate wanted size for the widget
    self.size_want = {
        w = 0,
        h = 0,
    }
end

function Widget:update_rect(available_rect)
    -- update widget rect based on available space and fill mode

    -- use full width
    if self.fill_mode == "full" or self.fill_mode == "horizontal" then
        self.rect.x = available_rect.x
        self.rect.w = available_rect.w
    end

    -- use full height
    if self.fill_mode == "full" or self.fill_mode == "vertical" then
        self.rect.y = available_rect.y
        self.rect.h = available_rect.h
    end

    -- use available width
    if self.fill_mode == "none" or self.fill_mode == "horizontal" then
        if self.v_align == "top" then
            self.rect.y = available_rect.y
        elseif self.v_align == "bottom" then
            self.rect.y = available_rect.y + available_rect.h - self.size_want.h
        else
            self.rect.y = available_rect.y + math.floor((available_rect.h - self.size_want.h) / 2)
        end
        self.rect.h = self.size_want.h
    end

    -- use available height
    if self.fill_mode == "none" or self.fill_mode == "vertical" then
        if self.h_align == "left" then
            self.rect.x = available_rect.x
        elseif self.h_align == "right" then
            self.rect.x = available_rect.x + available_rect.w - self.size_want.w
        else
            self.rect.x = available_rect.x + math.floor((available_rect.w - self.size_want.w) / 2)
        end

        self.rect.w = self.size_want.w
    end
end

function Widget:draw()
    if self.visible then
        GUI.render:blit_rect(self.rect.x, self.rect.y, self.rect.w, self.rect.h, self.bg_color)
    end
end

function Widget:set_visible(visible)
    visible = visible or GUI.root == self
    if self.visible ~= visible then
        self.visible = visible
        GUI.redraw = true
    end
end

function Widget:set_fill_mode(fill_mode)
    if self.fill_mode ~= fill_mode then
        self.fill_mode = fill_mode
        GUI.resize = true
    end
end

function Widget:set_h_align(h_align)
    if self.h_align ~= h_align then
        self.h_align = h_align
        GUI.resize = true
    end
end

function Widget:set_v_align(v_align)
    if self.v_align ~= v_align then
        self.v_align = v_align
        GUI.resize = true
    end
end

function Widget:set_fg_color(fg_color)
    if self.fg_color ~= fg_color then
        self.fg_color = fg_color
        if self.visible then
            GUI.redraw = true
        end
    end
end

function Widget:set_bg_color(bg_color)
    if self.bg_color ~= bg_color then
        self.bg_color = bg_color
        if self.visible then
            GUI.redraw = true
        end
    end
end

function Widget:is_focused()
    return GUI.focused == self
end

function Widget:set_focused()
    -- set this widget as focused
    -- if it is not visible, then set no widget as focused
    if self:is_focused() then
        return
    end

    if self.visible then
        if GUI.focused and GUI.focused.on_lose_focus then
            GUI.focused:on_lose_focus()
        end

        GUI.focused = self
        term.setCursorBlink(false)
        if self.on_focus then
            self:on_focus()
        end
    else
        GUI.focused = nil
    end
end

function Widget:get_widget_by_pos(x, y)
    -- get the widget at the given position

    if self.visible and x >= self.rect.x and x < self.rect.x + self.rect.w and y >= self.rect.y and y < self.rect.y + self.rect.h then
        return self
    end
end

function Widget:handle_click(btn, x, y)
    self:set_focused()
    if self.on_click then
        self:on_click(btn, x, y)
    end
end

function Widget:handle_tick()
    if self.on_tick then
        self:on_tick()
    end
end

function Widget:handle_event(event, ...)
    if self.event_handlers[event] then
        self.event_handlers[event](self, ...)
    end
end

local Frame = Widget:new()
Frame.__index = Frame

function Frame:new()
    o = Widget:new()
    setmetatable(o, self)
    o.super = Widget
    return o
end

function Frame:update_size_want()
    if self.child then
        self.child:update_size_want()
        self.size_want.w = self.child.size_want.w + self.padding.left + self.padding.right
        self.size_want.h = self.child.size_want.h + self.padding.top + self.padding.bottom
    else
        self.size_want.w = self.padding.left + self.padding.right
        self.size_want.h = self.padding.top + self.padding.bottom
    end
end

function Frame:update_rect(available_rect)
    self.super.update_rect(self, available_rect)

    if self.child then
        -- resize child to fit available space
        local child_rect = {
            x = self.rect.x + self.padding.left,
            y = self.rect.y + self.padding.top,
            w = self.rect.w - self.padding.left - self.padding.right,
            h = self.rect.h - self.padding.top - self.padding.bottom
        }

        self.child:update_rect(child_rect)
    end
end

function Frame:draw()
    self.super.draw(self)

    if self.child and self.visible then
        self.child:draw()
    end
end

function Frame:get_widget_by_pos(x, y)
    if self.visible and x >= self.rect.x and x <= self.rect.x + self.rect.w and y >= self.rect.y and y <= self.rect.y + self.rect.h then
        if self.child then
            return self.child:get_widget_by_pos(x, y) or self
        end
    end
end

function Frame:handle_tick()
    self.super.handle_tick(self)

    if self.child then
        self.child:handle_tick()
    end
end

function Frame:handle_event(event, ...)
    self.super.handle_event(self, event, ...)

    if self.child then
        self.child:handle_event(event, ...)
    end
end

function Frame:add_child(widget)
    -- add a child widget
    self.child = widget
    widget.parent = self
    if not widget.bg_color then
        widget.bg_color = self.bg_color
    end

    GUI.resize = true
end

function Frame:get_child()
    return self.child
end

function Frame:remove_child()
    -- remove child widget
    if self.child then
        self.child.parent = nil
        self.child = nil
        return true
    end

    GUI.resize = true
end

local Grid = Widget:new()
Grid.__index = Grid

function Grid:new(w, h)
    o = Widget:new()
    setmetatable(o, self)
    o.super = Widget
    o.grid_size = {
        w = w,
        h = h,
    }
    o.weights = {
        rows = {},
        cols = {},
    }

    for x = 1, w do
        o.weights.cols[x] = 1
    end
    for y = 1, h do
        o.weights.rows[y] = 1
    end

    o.grid = {}
    return o
end

function Grid:update_size_want()
    -- recalculate wanted size for the widget
    self.size_want.row_lengths = {}
    self.size_want.col_lengths = {}
    self.size_want.row_widths = {}
    self.size_want.col_widths = {}
    for x = 1, self.grid_size.w do
        self.size_want.col_lengths[x] = 0
        self.size_want.col_widths[x] = 0
        for y = 1, self.grid_size.h do
            self.size_want.row_lengths[y] = self.size_want.row_lengths[y] or 0
            self.size_want.row_widths[y] = self.size_want.row_widths[y] or 0
            key = x .. "." .. y
            if self.grid[key] then
                self.grid[key]:update_size_want()
                self.size_want.row_lengths[y] = self.size_want.row_lengths[y] + self.grid[key].size_want.w
                self.size_want.row_widths[y] = math.max(self.size_want.row_widths[y], self.grid[key].size_want.h)
                self.size_want.col_lengths[x] = self.size_want.col_lengths[x] + self.grid[key].size_want.h
                self.size_want.col_widths[x] = math.max(self.size_want.col_widths[x], self.grid[key].size_want.w)
            end
        end
    end

    self.size_want.w = self.padding.left + self.padding.right + math.max(unpack(self.size_want.row_lengths))
    self.size_want.h = self.padding.top + self.padding.bottom + math.max(unpack(self.size_want.col_lengths))
end

function Grid:update_rect(available_rect)
    self.super.update_rect(self, available_rect)

    local extra_space = {
        w = self.rect.w - self.size_want.w,
        h = self.rect.h - self.size_want.h,
    }
    
    -- normalize the weights, and calculate height of rows and width of columns
    local cell_sizes = {
        rows = {},
        cols = {},
    }

    for i, weight in ipairs(self.weights.rows) do
        local weight_norm = weight / util.sum(unpack(self.weights.rows))
        cell_sizes.rows[i] = self.size_want.row_widths[i] + math.floor(extra_space.h * weight_norm + 0.5)
    end

    for i, weight in ipairs(self.weights.cols) do
        local weight_norm = weight / util.sum(unpack(self.weights.cols))
        cell_sizes.cols[i] = self.size_want.col_widths[i] + math.floor(extra_space.w * weight_norm + 0.5)
    end

    -- assign children the appropriate rects for their row/col position
    for x = 1, self.grid_size.w do
        for y = 1, self.grid_size.h do
            key = x .. "." .. y
            if self.grid[key] then
                local child_rect = {
                    x = self.rect.x + self.padding.left + util.sum(unpack(cell_sizes.cols, 1, x - 1)),
                    y = self.rect.y + self.padding.top + util.sum(unpack(cell_sizes.rows, 1, y - 1)),
                    w = cell_sizes.cols[x],
                    h = cell_sizes.rows[y],
                }

                self.grid[key]:update_rect(child_rect)
            end
        end
    end
end

function Grid:draw()
    self.super.draw(self)

    for x = 1, self.grid_size.w do
        for y = 1, self.grid_size.h do
            key = x .. "." .. y
            if self.grid[key] then
                self.grid[key]:draw()
            end
        end
    end
end

function Grid:get_widget_by_pos(x, y)
    if x >= self.rect.x and x <= self.rect.x + self.rect.w and y >= self.rect.y and y <= self.rect.y + self.rect.h then
        for h = 1, self.grid_size.w do
            for k = 1, self.grid_size.h do
                key = h .. "." .. k
                if self.grid[key] then
                    widget = self.grid[key]:get_widget_by_pos(x, y)
                    if widget then
                        return widget
                    end
                end
            end
        end

        return self
    end
end

function Grid:handle_tick()
    self.super.handle_tick(self)

    for h = 1, self.grid_size.w do
        for k = 1, self.grid_size.h do
            key = h .. "." .. k
            if self.grid[key] then
                self.grid[key]:handle_tick()
            end
        end
    end
end

function Grid:handle_event(event, ...)
    self.super.handle_event(self, event, ...)

    for h = 1, self.grid_size.w do
        for k = 1, self.grid_size.h do
            key = h .. "." .. k
            if self.grid[key] then
                self.grid[key]:handle_event(event, ...)
            end
        end
    end
end

function Grid:add_child(widget, x, y)
    if x > 0 and x <= self.grid_size.w and y > 0 and y <= self.grid_size.h then
        self.grid[x .. "." .. y] = widget
        widget.parent = self
        if not widget.bg_color then
            widget.bg_color = self.bg_color
        end

        return true
    end

    GUI.resize = true
end

function Grid:get_child(x, y)
    return self.grid[x .. "." .. y]
end

function Grid:remove_child(x, y)
    key = x .. "." .. y
    if self.grid[key] then
        self.grid[key].parent = nil
        self.grid[key] = nil
    end

    GUI.resize = true
end

local Text = Widget:new()
Text.__index = Text

function Text:new(text)
    o = Widget:new()
    setmetatable(o, self)
    o.super = Widget
    o.text = text or ""
    o.text_align = "center"
    o.text_changed = false
    o.wrapping = true
    return o
end

function Text:update_size_want()
    -- recalculate wanted size for the widget
    local max_len = self.text:len()
    if self.wrapped_text then
        max_len = 0
        for i, line in ipairs(self.wrapped_text) do
            if line:len() > max_len then
                max_len = line:len()
            end
        end
    end

    self.size_want.w = max_len + self.padding.left + self.padding.right
    self.size_want.h = self.padding.top + self.padding.bottom + (self.wrapped_text and #self.wrapped_text or 1)
end

function Text:update_rect(available_rect)
    self.super.update_rect(self, available_rect)

    if self.text_changed then
        self.text_changed = false
        GUI.resize = true
        if self.wrapping and self.text:len() + self.padding.left + self.padding.right > available_rect.w then
            self.wrapped_text = util.wrap_text(self.text, available_rect.w - self.padding.left - self.padding.right)
        else
            self.wrapped_text = nil
        end
    end
end

function Text:draw()
    o.super.draw(self)

    local x_offset = 0
    local y_offset = self.padding.top + math.floor((self.rect.h - self.padding.top - self.padding.bottom - 1) / 2)
    if self.text_align == "left" then
        x_offset = self.padding.left
    elseif self.text_align == "right" then
        x_offset = self.rect.w - self.text:len() - self.padding.right + 1
    else
        x_offset = self.padding.left + math.floor((self.rect.w - self.padding.left - self.padding.right - self.text:len()) / 2)
    end

    local shown_text = self.text
    if self.wrapped_text then
        x_offset = self.padding.left
        shown_text = ""
        for i, line in ipairs(self.wrapped_text) do
            local spacing = ""
            if self.text_align == "right" then
                spacing = string.rep(" ", self.rect.w - self.padding.left - self.padding.right - line:len())
            elseif self.text_align == "center" then
                spacing = string.rep(" ", math.floor((self.rect.w - self.padding.left - self.padding.right - line:len()) / 2) - 1)
            end

            shown_text = shown_text .. spacing .. line .. "\n"
        end

        y_offset = y_offset - math.ceil(#self.wrapped_text / 2) + 1
    end

    GUI.render:blit_text(shown_text, self.rect.x + x_offset, self.rect.y + y_offset, self.fg_color, self.bg_color)
end

function Text:set_text(text)
    if self.text ~= text then
        self.text = text
        self.text_changed = true
        GUI.resize = true
    end
end

local Input = Widget:new()
Input.__index = Input

function Input:new(text, hint_text, box_width, hint_color, box_color)
    o = Widget:new()
    setmetatable(o, self)
    o.super = Widget
    o.text = text or ""
    o.box_width = box_width or 10
    o.box_color = box_color or colors.gray
    o.hint_text = hint_text or ""
    o.hint_color = hint_color or colors.light_gray
    o.cursor_index = 1
    o.scroll = 1
    return o
end

function Input:update_size_want()
    -- recalculate wanted size for the widget
    self.size_want.w = self.box_width + self.padding.left + self.padding.right
    self.size_want.h = self.padding.top + self.padding.bottom + 1
end

function Input:update_rect(available_rect)
    self.super.update_rect(self, available_rect)

    if self:is_focused() then
        self:set_cursor_index()
    end
end

function Input:draw()
    o.super.draw(self)

    local actual_box_width = self.rect.w - self.padding.left - self.padding.right
    local y_offset = self.padding.top + math.floor((self.rect.h - self.padding.top - self.padding.bottom - 1) / 2)

    local shown_text = self.text:len() > 0 and self.text:sub(self.scroll) or self.hint_text
    local text_color = self.text:len() > 0 and self.fg_color or self.hint_color
    GUI.render:blit_rect(self.rect.x + self.padding.left, self.rect.y + y_offset, actual_box_width, 1, self.box_color)
    GUI.render:blit_text(shown_text:sub(1, actual_box_width), self.rect.x + self.padding.left, self.rect.y + y_offset, text_color, self.box_color)
end

function Input:set_focused()
    self.super.set_focused(self)

    term.setCursorBlink(true)
    self:set_cursor_index()
end

function Input:handle_click(btn, x, y)
    self.super.handle_click(self, btn, x, y)

    local local_x = x - self.rect.x
    local local_y = y - self.rect.y
    if local_x >= self.padding.left and local_x <= self.rect.w - self.padding.right and local_y == self.padding.top + math.floor((self.rect.h - self.padding.top - self.padding.bottom - 1) / 2) then
        local clicked_cursor_index = local_x - self.padding.left + self.scroll
        self:set_cursor_index(clicked_cursor_index)
    end
end

function Input:handle_event(event, ...)
    self.super.handle_event(self, event, ...)

    if self:is_focused() then
        if event == "key" then
            local key = ...
            if key == keys.backspace then
                self.text = self.text:sub(1, math.max(0, self.cursor_index - 2)) .. self.text:sub(self.cursor_index)
                self:set_cursor_index(self.cursor_index - 1)
                GUI.redraw = true
            elseif key == keys.delete then
                self.text = self.text:sub(1, self.cursor_index - 1) .. self.text:sub(self.cursor_index + 1)
                GUI.redraw = true
            elseif key == keys.left then
                self:set_cursor_index(self.cursor_index - 1)
            elseif key == keys.right then
                self:set_cursor_index(self.cursor_index + 1)
            elseif key == keys.enter and self.on_enter then
                self:on_enter()
            end
        end

        if event == "char" then
            local char = ...
            self.text = self.text:sub(1, self.cursor_index - 1) .. char .. self.text:sub(self.cursor_index)
            self:set_cursor_index(self.cursor_index + 1)
            GUI.redraw = true
        end
    end
end

function Input:set_cursor_index(index)
    if index then
        self.cursor_index = index
    end

    self.cursor_index = math.max(1, math.min(self.cursor_index, self.text:len() + 1))
    local actual_box_width = self.rect.w - self.padding.left - self.padding.right
    local box_cursor_x = self.cursor_index - self.scroll + 1
    if box_cursor_x > actual_box_width then
        self.scroll = self.scroll + 1
        GUI.redraw = true
    end

    if box_cursor_x <= 1 and self.scroll > 1 then
        self.scroll = self.scroll - 1
        GUI.redraw = true
    end

    local y_offset = self.padding.top + math.floor((self.rect.h - self.padding.top - self.padding.bottom - 1) / 2)
    term.setCursorPos(self.rect.x + self.padding.left + self.cursor_index - self.scroll, self.rect.y + y_offset)
end

function Input:set_text(text)
    if self.text ~= text then
        self.text = text
        self:set_cursor_index()
        GUI.redraw = true
    end
end

function Input:set_hint_text(text)
    if self.hint_text ~= text then
        self.hint_text = text
        GUI.redraw = true
    end
end

function Input:set_box_width(width)
    if self.box_width ~= width then
        self.box_width = width
        GUI.resize = true
        self:set_cursor_index()
    end
end

function Input:set_hint_color(color)
    if self.hint_color ~= color then
        self.hint_color = color
        GUI.redraw = true
    end
end

function Input:set_box_color(color)
    if self.box_color ~= color then
        self.box_color = color
        GUI.redraw = true
    end
end

return {
    colors = colors,
    colours = colors,
    util = util,
    GUI = GUI,
    Widget = Widget,
    Frame = Frame,
    Grid = Grid,
    Text = Text,
    Input = Input,
}
