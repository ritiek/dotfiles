{
    "_": "", 
    "buttons": {
        "A": {
            "action": "button(Keys.BTN_GAMEPAD)"
        }, 
        "B": {
            "action": "button(Keys.BTN_EAST)"
        }, 
        "BACK": {
            "action": "button(Keys.BTN_SELECT)"
        }, 
        "C": {
            "action": "hold(menu('Default.menu'), menu('Default.menu'))"
        }, 
        "LB": {
            "action": "repeat(button(Keys.BTN_NORTH); sleep(0.010); button(Keys.BTN_WEST); sleep(0.280); button(Keys.BTN_WEST); sleep(0.010))"
        }, 
        "LGRIP": {
            "action": "button(Keys.BTN_GAMEPAD)"
        }, 
        "RB": {
            "action": "repeat(button(Keys.BTN_NORTH); sleep(0.020); button(Keys.BTN_WEST); sleep(0.360); button(Keys.BTN_WEST); sleep(0.020))", 
            "name": "Punch Grab"
        }, 
        "RGRIP": {
            "action": "button(Keys.BTN_NORTH)"
        }, 
        "RPAD": {
            "action": "button(Keys.BTN_THUMBR)"
        }, 
        "START": {
            "action": "button(Keys.BTN_START)"
        }, 
        "STICKPRESS": {
            "action": "button(Keys.BTN_THUMBL)"
        }, 
        "X": {
            "action": "button(Keys.BTN_NORTH)"
        }, 
        "Y": {
            "action": "button(Keys.BTN_WEST)"
        }
    }, 
    "cpad": {
        "action": "dpad(repeat(button(Keys.BTN_NORTH); sleep(0.020); button(Keys.BTN_WEST); sleep(0.360); button(Keys.BTN_WEST); sleep(0.020)), repeat(button(Keys.BTN_NORTH); sleep(0.020); button(Keys.BTN_WEST); sleep(0.360); button(Keys.BTN_WEST); sleep(0.020)), repeat(button(Keys.BTN_NORTH); sleep(0.020); button(Keys.BTN_WEST); sleep(0.360); button(Keys.BTN_WEST); sleep(0.020)), repeat(button(Keys.BTN_NORTH); sleep(0.020); button(Keys.BTN_WEST); sleep(0.360); button(Keys.BTN_WEST); sleep(0.020)))"
    }, 
    "gyro": {}, 
    "is_template": false, 
    "menus": {}, 
    "pad_left": {
        "action": "click(dpad(hatup(Axes.ABS_HAT0Y), hatdown(Axes.ABS_HAT0Y), hatleft(Axes.ABS_HAT0X), hatright(Axes.ABS_HAT0X)))"
    }, 
    "pad_right": {}, 
    "stick": {
        "action": "sens(1.2, 1.2, XY(axis(Axes.ABS_X), raxis(Axes.ABS_Y)))"
    }, 
    "trigger_left": {
        "action": "axis(Axes.ABS_Z)"
    }, 
    "trigger_right": {
        "action": "axis(Axes.ABS_RZ)"
    }, 
    "version": 1.4
}