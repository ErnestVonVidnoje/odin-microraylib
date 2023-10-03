package microraylib

import "core:strings"
import mu "vendor:microui"
import rl "vendor:raylib"

render :: proc(ctx: ^mu.Context) {
	rl.BeginScissorMode(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight())

	cmd: ^mu.Command
	for variant in mu.next_command_iterator(ctx, &cmd) {
		#partial switch cmd in variant {
		case ^mu.Command_Text:
			{
				font := cmd.font
                str := strings.clone_to_cstring(cmd.str)
                defer free(&str)
				rl.DrawTextEx(
					mufont_to_rlfont(font),
					str,
					rl.Vector2{auto_cast cmd.pos.x, auto_cast cmd.pos.y},
					auto_cast ctx.text_height(font),
					auto_cast ctx.style.spacing,
					transmute(rl.Color)cmd.color,
				)
			}

		case ^mu.Command_Rect:
			{
				using cmd.rect
				rl.DrawRectangle(x, y, w, h, transmute(rl.Color)cmd.color)
			}

		case ^mu.Command_Icon:
			{
				icon := "?"
				#partial switch cmd.id {
				case mu.Icon.CLOSE: icon = "x"
				case mu.Icon.CHECK: icon = "*"
				case mu.Icon.COLLAPSED: icon = "+"
				case mu.Icon.EXPANDED: icon = "-"
				}
				using cmd.rect
				rl.DrawText(strings.clone_to_cstring(icon), x, y, h, transmute(rl.Color)cmd.color)
			}

		case ^mu.Command_Clip:
			{
				using cmd.rect
				rl.EndScissorMode()
				rl.BeginScissorMode(x, y, w, h)
			}
		}
	}
}

@private
rlbuttons_to_mubuttons :: [?]struct{
    r: rl.MouseButton,
    m: mu.Mouse
}{
    { .LEFT,   .LEFT },
    { .RIGHT,  .RIGHT },
    { .MIDDLE, .MIDDLE },
}

@private
rlkeys_to_mukeys :: [?]struct{
    r: rl.KeyboardKey,
    m: mu.Key,
}{
    { .LEFT_SHIFT,    .SHIFT },
    { .LEFT_CONTROL,  .CTRL },
    { .LEFT_ALT,      .ALT },
    { .ENTER,         .RETURN },
    { .BACKSPACE,     .BACKSPACE },
    { .RIGHT_SHIFT,   .SHIFT },
    { .RIGHT_CONTROL, .CTRL },
    { .RIGHT_ALT,     .ALT },
    { .KP_ENTER,      .RETURN },
}

handle_input :: proc(ctx: ^mu.Context, text_buffer_size: int) -> bool  {
    pos := rl.GetMousePosition()
    x := cast(i32)pos[0]
    y := cast(i32)pos[1]
    mu.input_mouse_move(ctx, x, y)
    // Mouse Scroll
    {
        mvs := rl.GetMouseWheelMoveV()
        mu.input_scroll(ctx, auto_cast mvs[0], auto_cast mvs[1])
    }
    // Mouse Buttons
    {
        for button in rlbuttons_to_mubuttons {
            if rl.IsMouseButtonPressed(button.r) {
                mu.input_mouse_down(ctx, x, y, button.m)
            } else if rl.IsMouseButtonReleased(button.r) {
                mu.input_mouse_up(ctx, x, y, button.m)
            }
        }
    }
    // Keyboard
    {
        for key in rlkeys_to_mukeys {
            if rl.IsKeyPressed(key.r) {
                mu.input_key_down(ctx, key.m)
            } else if rl.IsKeyReleased(key.r) {
                mu.input_key_up(ctx, key.m)
            }
        }
    }
    // Text
    {
        builder := strings.Builder{}
        strings.builder_init_len(&builder, text_buffer_size)
        defer strings.builder_destroy(&builder)
        for i in 0..<text_buffer_size {
            _, err := strings.write_rune(&builder, rl.GetCharPressed())
            if err != nil {
                return false
            }
        }
        mu.input_text(ctx, strings.to_string(builder))
    }
    return true
}

setup_font :: proc(ctx: ^mu.Context, font: ^rl.Font) {
    text_width :: proc(font: mu.Font, str: string) -> i32 {
        font := mufont_to_rlfont(font)
        str := strings.clone_to_cstring(str)
        defer free(&str)
        size := rl.MeasureTextEx(font, str, auto_cast font.baseSize, 1)
        return auto_cast size.x
    }

    text_height :: proc(font: mu.Font) -> i32 {
        return mufont_to_rlfont(font).baseSize
    }
    ctx.style.font = auto_cast font
    ctx.text_width = text_width
    ctx.text_height = text_height
    ctx.style.spacing = 1
}

@private
mufont_to_rlfont :: proc(font: mu.Font) -> rl.Font {
    return rl.GetFontDefault() if font == nil else (cast(^rl.Font)font)^
}
