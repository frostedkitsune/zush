const std = @import("std");
const vaxis = @import("vaxis");
const zush = @import("zush");
const header = @import("../widget/header.zig");
const vxfw = vaxis.vxfw;
// -- TYPEs
const Border = vxfw.Border;
const Button = vxfw.Button;
const Center = vxfw.Center;

const drive_options = [_][]const u8{ "Network USB", "KeyBoard", "USB KingDom", "SanDisk (32 GB)" };
const boot_options = [_][]const u8{ "Zorin_OS_99.7_Ultimate_procode_LTS.iso", "Ubuntu_24.04_LTS.iso", "Windows_11_ISO.iso" };
const scheme_options = [_][]const u8{ "MBR", "GPT" };
const target_options = [_][]const u8{ "BIOS or UEFI", "UEFI (non CSM)" };

const all_options = [_][]const []const u8{ &drive_options, &boot_options, &scheme_options, &target_options };

pub const Model = struct {
    focused_row_index: usize = 0, // 0 = Devices, 1 = Boot Selection, 2 = Scheme, 3 = Target
    selected_indices: [4]usize = [_]usize{0} ** 4,

    is_started: bool = false,
    const MAX_ROWS: usize = 4;

    // --- Helper Widget Interface ---
    pub fn widget(self: *Model) vxfw.Widget {
        return .{
            .userdata = self,
            .eventHandler = Model.typeErasedEventHandler,
            .drawFn = Model.typeErasedDrawFn,
        };
    }

    // --- Event Handling ---
    fn typeErasedEventHandler(ptr: *anyopaque, ctx: *vxfw.EventContext, event: vxfw.Event) anyerror!void {
        const self: *Model = @ptrCast(@alignCast(ptr));
        switch (event) {
            .init => return ctx.requestFocus(self.widget()),
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true }) or key.matches('q', .{})) {
                    ctx.quit = true;
                    return;
                }

                // Move highlight UP
                if (key.matches(vaxis.Key.up, .{})) {
                    if (self.focused_row_index > 0) self.focused_row_index -= 1;
                    ctx.consumeAndRedraw();
                    return;
                }

                // Move highlight DOWN
                if (key.matches(vaxis.Key.down, .{})) {
                    if (self.focused_row_index < MAX_ROWS - 1) self.focused_row_index += 1;
                    ctx.consumeAndRedraw();
                    return;
                }

                // Select NEXT option (Right)
                if (key.matches(vaxis.Key.right, .{})) {
                    const index = self.focused_row_index;
                    self.selected_indices[index] = (self.selected_indices[index] + 1) % all_options[index].len;
                    ctx.consumeAndRedraw();
                    return;
                }

                // Select PREVIOUS option (Left)
                if (key.matches(vaxis.Key.left, .{})) {
                    const index = self.focused_row_index;
                    if (self.selected_indices[index] > 0) {
                        self.selected_indices[index] -= 1;
                    } else {
                        self.selected_indices[index] = all_options[index].len - 1;
                    }
                    ctx.consumeAndRedraw();
                    return;
                }
            },
            .focus_in => return ctx.requestFocus(self.widget()),
            else => {},
        }
    }

    // --- 3. Drawing ---
    fn typeErasedDrawFn(ptr: *anyopaque, ctx: vxfw.DrawContext) std.mem.Allocator.Error!vxfw.Surface {
        const self: *Model = @ptrCast(@alignCast(ptr));
        const max_size = ctx.max.size();
        const arena = ctx.arena;

        // Initialize using the new unmanaged .empty syntax
        var subsurfaces: std.ArrayList(vxfw.SubSurface) = .empty;
        var current_row: u16 = 0;

        // Define Styles
        const row_active: vaxis.Style = .{ .bg = .{ .rgb = .{ 220, 220, 220 } }, .fg = .{ .rgb = .{ 0, 0, 0 } }, .bold = true };
        const row_inactive: vaxis.Style = .{ .bg = .default, .fg = .default };

        // --- Draw Top UI ---
        // const header_text: vxfw.Text = .{ .text = "[ Flasher ] -- ISO Info", .style = .{ .bold = true } };
        const tabList = try header.create_headerEndingWithUnicode(arena, max_size.width, "--[ Flasher ]-- ISO Info ", "-");
        //Pass 'arena' as the first argument to append
        try subsurfaces.append(arena, .{ .origin = .{ .row = current_row, .col = 0 }, .surface = try tabList.draw(ctx) });
        current_row += 2;

        const drive_header = try header.create_headerStartingWithUnicode(arena, max_size.width, "Drive Properties::", ":");
        //Pass 'arena'
        try subsurfaces.append(arena, .{ .origin = .{ .row = current_row, .col = 0 }, .surface = try drive_header.draw(ctx) });
        current_row += 2;

        const RowData = struct { label: []const u8, opt: []const u8 };
        const rows = [_]RowData{
            .{ .label = "Devices", .opt = drive_options[self.selected_indices[0]] },
            .{ .label = "Boot Selection", .opt = boot_options[self.selected_indices[1]] },
            .{ .label = "Scheme", .opt = scheme_options[self.selected_indices[2]] },
            .{ .label = "Target", .opt = target_options[self.selected_indices[3]] },
        };

        for (rows, 0..) |rd, i| {
            const is_focused = (self.focused_row_index == i);
            const current_style = if (is_focused) row_active else row_inactive;

            // 2. Create independent copies of the style to modify
            var arrow_style = current_style;
            var text_style = current_style;

            // 3. Add custom colors and formatting ONLY when the row is focused
            if (is_focused) {
                // vaxis colors can usually be set via RGB or ANSI index.
                // Here we make the arrows a bright color and bold them.

                arrow_style.fg = .{ .rgb = .{ 61, 105, 195 } }; // A nice cyan/mint color
                arrow_style.bold = true;
                text_style.bold = true;
            } else {
                text_style.fg = .{ .rgb = .{ 225, 225, 193 } };
            }

            // 1. The Left Label
            const lbl_w: vxfw.Text = .{ .text = rd.label };

            // 2. The Arrows (Notice the extra spaces added so it breathes!)
            const left_arrow: vxfw.Text = .{ .text = if (is_focused) "<< " else "   ", .style = arrow_style };
            const right_arrow: vxfw.Text = .{ .text = if (is_focused) " >>" else "   ", .style = arrow_style, .text_align = .right };

            // 3. The Text Options
            const opt_text: vxfw.Text = .{ .text = rd.opt, .style = text_style, .text_align = .center };

            // 4. The "Glued" Inner Row
            // We REMOVED .flex = 1 here. Now they will sit shoulder-to-shoulder.
            const tight_row: vxfw.FlexRow = .{ .children = &.{
                .{ .widget = left_arrow.widget() },
                .{ .widget = opt_text.widget() },
                .{ .widget = right_arrow.widget() },
            } };

            // 5. Center the entire tight block!
            const centered_group: vxfw.Center = .{ .child = tight_row.widget() };

            // 6. The Outer Row (Label on left, Options on right)
            const fr: vxfw.FlexRow = .{
                .children = &.{
                    .{ .widget = lbl_w.widget(), .flex = 1 },
                    // We pass the centered group here, allowing it to take up the right side
                    .{ .widget = centered_group.widget(), .flex = 2 },
                },
            };

            // 7. Constrain the height to 1 row to fix the vertical offset bug
            var row_ctx = ctx;
            row_ctx.max.height = 1;
            row_ctx.min.height = 1;
            if (ctx.max.width) |w| {
                row_ctx.max.width = w -| 3;
            }
            if (@typeInfo(@TypeOf(ctx.min.width)) == .optional) {
                if (ctx.min.width) |min_w| row_ctx.min.width = min_w -| 3;
            } else {
                row_ctx.min.width = ctx.min.width -| 3;
            }
            try subsurfaces.append(arena, .{ .origin = .{ .row = current_row, .col = 3 }, .surface = try fr.draw(row_ctx) });

            current_row += 2;
        }
        current_row += 1;
        const format_header = try header.create_headerStartingWithUnicode(arena, max_size.width, "Format Options::", ":");

        // FIXED: Pass 'arena'
        try subsurfaces.append(arena, .{ .origin = .{ .row = current_row, .col = 0 }, .surface = try format_header.draw(ctx) });
        current_row += 4;

        // --- Draw Start Button ---
        const btn_text_str = "[   S T A R T   ]";

        const btn_widget: vxfw.Text = .{ .text = btn_text_str, .text_align = .center };

        try subsurfaces.append(arena, .{ .origin = .{ .row = current_row, .col = 0 }, .surface = try btn_widget.draw(ctx) });

        return .{
            .size = max_size,
            .widget = self.widget(),
            .buffer = &.{},
            // FIXED: toOwnedSlice now requires the allocator to be passed in
            .children = try subsurfaces.toOwnedSlice(arena),
        };
    }
};
