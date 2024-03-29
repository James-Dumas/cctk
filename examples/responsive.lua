-- Example of responsiveness.
-- Enter text into the input widget, and the text widget will display the text,
-- automatically wrapping it and resizing the container as needed.

os.loadAPI("cctk/cctk")

-- text widget
local text = cctk.Text:new("Hello World!")
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
text_frame.bg_color = cctk.colors.black
text_frame.fill_mode = "full"
text_frame.padding = {
    left = 2,
    right = 2,
    top = 1,
    bottom = 1
}

-- text input widget
local input = cctk.Input:new(nil, "Type Something Here...", 30)
input.h_align = "left"

-- frame to contain the input widget
local input_frame = cctk.Frame:new()
input_frame.fill_mode = "full"
input_frame.bg_color = cctk.colors.green
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

-- add widgets to their frames
text_frame:add_child(text)
input_frame:add_child(input)

-- exit button widget: a text widget with an on click function
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
grid:add_child(text_frame, 1, 2)
grid:add_child(input_frame, 1, 3)
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
