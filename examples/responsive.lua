-- Example of responsiveness.
-- Enter text into the input widget, and the text widget will display the text,
-- automatically wrapping it and resizing the container as needed.

os.loadAPI("/lib/cctk")

-- text widget
local text = cctk.Text:new()
text.bg_color = cctk.colors.blue
text.text_align = "left"
text.visible = false
text.padding = {
    left = 2,
    right = 2,
    top = 1,
    bottom = 1
}

-- frame to contain the text widget
local text_frame = cctk.Frame:new()
text_frame.fill_mode = "full"
text_frame.padding = {
    left = 2,
    right = 2,
    top = 1,
    bottom = 1
}

-- another text widget to appear/disappear next to the other one
local text2 = cctk.Text:new("o o\n^\n\\___/", "center")
text2.bg_color = cctk.colors.orange
text2.padding = {
    left = 1,
    right = 1,
    top = 1,
    bottom = 1
}

-- frame to contain the text2 widget
local text2_frame = cctk.Frame:new()
text2_frame.fill_mode = "full"
text2_frame.padding = {
    left = 2,
    right = 2,
    top = 1,
    bottom = 1
}

-- add widgets to their frames
text_frame:add_child(text)
text2_frame:add_child(text2)

-- put the text widget frames together in a grid
local text_grid = cctk.Grid:new(2, 1)
text_grid.bg_color = cctk.colors.black
text_grid.fill_mode = "full"
-- set column weights to control relative sizes of the grid's widgets
text_grid.weights.cols = {
    1,
    0,
}

text_grid:add_child(text_frame, 1, 1)
text_grid:add_child(text2_frame, 2, 1)

-- text input widget
local input = cctk.Input:new(nil, "Type Something Here...", 28)
input.h_align = "left"
input.v_align = "bottom"

-- frame to contain the input widget
local input_frame = cctk.Frame:new()
input_frame.fill_mode = "full"
input_frame.padding = {
    left = 3,
    right = 3,
    top = 1,
    bottom = 1
}

-- this function will run when the input text is changed
function input:on_change()
    -- set text widget visible if input is not empty
    text:set_visible(input.text:len() > 0)
    -- set text widget's text to input widget's text
    text:set_text(input.text)
end

-- button to show/hide the second text widget
local show_text2_button = cctk.Text:new("Click\nme!", "center")
show_text2_button.bg_color = cctk.colors.brown
show_text2_button.h_align = "right"
show_text2_button.v_align = "bottom"
show_text2_button.padding = {
    left = 1,
    right = 1,
    top = 0,
    bottom = 0,
}

function show_text2_button:on_click(btn, x, y)
    if btn == 1 then
        if not text_grid:remove_child(2, 1) then
            text_grid:add_child(text2_frame, 2, 1)
        end
    end
end

local show_text2_frame = cctk.Frame:new()
show_text2_frame.fill_mode = "full"
show_text2_frame.bg_color = cctk.colors.light_blue
show_text2_frame.padding = {
    left = 1,
    right = 2,
    top = 1,
    bottom = 1
}

-- add widgets to their frames
input_frame:add_child(input)
show_text2_frame:add_child(show_text2_button)

-- put the input & button widget frames into a grid
local inputs_grid = cctk.Grid:new(2, 1)
inputs_grid.bg_color = cctk.colors.green
inputs_grid.fill_mode = "full"
-- set column weights to control relative sizes of the grid's widgets
inputs_grid.weights.cols = {
    1,
    0,
}

inputs_grid:add_child(input_frame, 1, 1)
inputs_grid:add_child(show_text2_frame, 2, 1)

-- exit button widget, will exit GUI main loop when clicked
local exit_button = cctk.Text:new("X")
exit_button.bg_color = cctk.colors.red
exit_button.h_align = "right"
exit_button.padding.left = 1
-- set on click function to exit GUI main loop
function exit_button:on_click(btn, x, y)
    if btn == 1 then
        cctk.GUI.exit = true
    end
end

-- add widgets to grid
local grid = cctk.Grid:new(1, 3)
grid.bg_color = cctk.colors.gray
grid:add_child(exit_button, 1, 1)
grid:add_child(text_grid, 1, 2)
grid:add_child(inputs_grid, 1, 3)
-- set row weights to control relative sizes of the grid's widgets
grid.weights.rows = {
    0,
    3,
    1,
}

-- initialize GUI with grid as root widget
cctk.GUI:init(grid)
-- enter GUI main loop
cctk.GUI:main()
