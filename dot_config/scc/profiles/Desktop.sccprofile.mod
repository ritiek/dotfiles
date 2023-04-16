{
    "_": "", 
    "buttons": {
        "A": {
            "action": "button(Keys.KEY_ENTER)"
        }, 
        "B": {
            "action": "button(Keys.KEY_ESC)"
        }, 
        "BACK": {
            "action": "button(Keys.KEY_BACKSPACE)"
        }, 
        "C": {
            "action": "hold(menu('Default.menu'), menu('Default.menu'))"
        }, 
        "CPADPRESS": {
            "action": "button(Keys.BTN_MOUSE)"
        }, 
        "LB": {
            "action": "button(Keys.KEY_LEFTCTRL)"
        }, 
        "LGRIP": {
            "action": "button(Keys.BTN_NORTH)"
        }, 
        "RB": {
            "action": "button(Keys.KEY_LEFTALT)"
        }, 
        "RPAD": {
            "action": "button(Keys.BTN_MOUSE)"
        }, 
        "START": {
            "action": "button(Keys.KEY_LEFTSHIFT)"
        }, 
        "X": {
            "action": "button(Keys.KEY_SPACE)"
        }, 
        "Y": {
            "action": "button(Keys.KEY_TAB)"
        }
    }, 
    "cpad": {
        "action": "mouse()"
    }, 
    "dpad": {}, 
    "gyro": {}, 
    "is_template": false, 
    "menus": {}, 
    "pad_left": {
        "action": "feedback(LEFT, 4096, 16, ball(XY(mouse(Rels.REL_HWHEEL, 1.0), mouse(Rels.REL_WHEEL, 1.0))))"
    }, 
    "pad_right": {
        "action": "smooth(8, 0.78, 2.0, feedback(RIGHT, 256, ball(mouse())))"
    }, 
    "rstick": {}, 
    "stick": {
        "action": "dpad(button(Keys.KEY_UP), button(Keys.KEY_DOWN), button(Keys.KEY_LEFT), button(Keys.KEY_RIGHT))"
    }, 
    "trigger_left": {
        "action": "button(Keys.BTN_RIGHT)"
    }, 
    "trigger_right": {
        "action": "button(Keys.BTN_MOUSE)"
    }, 
    "version": 1.4
}