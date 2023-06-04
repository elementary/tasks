/*
* Copyright 2019 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
*/

public class Tasks.Widgets.ListSettingsPopover : Gtk.Popover {
    public E.Source source { get; set; }

    private Gtk.CheckButton color_button_red;
    private Gtk.CheckButton color_button_orange;
    private Gtk.CheckButton color_button_yellow;
    private Gtk.CheckButton color_button_green;
    private Gtk.CheckButton color_button_mint;
    private Gtk.CheckButton color_button_blue;
    private Gtk.CheckButton color_button_purple;
    private Gtk.CheckButton color_button_pink;
    private Gtk.CheckButton color_button_brown;
    private Gtk.CheckButton color_button_slate;
    private Gtk.CheckButton color_button_none;

    construct {
        color_button_blue = new Gtk.CheckButton ();

        unowned Gtk.StyleContext color_button_blue_context = color_button_blue.get_style_context ();
        color_button_blue_context.add_class (Granite.STYLE_CLASS_COLOR_BUTTON);
        color_button_blue_context.add_class ("blue");

        color_button_mint = new Gtk.CheckButton () {
            group = color_button_blue
        };

        unowned Gtk.StyleContext color_button_mint_context = color_button_mint.get_style_context ();
        color_button_mint_context.add_class (Granite.STYLE_CLASS_COLOR_BUTTON);
        color_button_mint_context.add_class ("mint");

        color_button_green = new Gtk.CheckButton () {
            group = color_button_blue
        };

        unowned Gtk.StyleContext color_button_green_context = color_button_green.get_style_context ();
        color_button_green_context.add_class (Granite.STYLE_CLASS_COLOR_BUTTON);
        color_button_green_context.add_class ("green");

        color_button_yellow = new Gtk.CheckButton () {
            group = color_button_blue
        };

        unowned Gtk.StyleContext color_button_yellow_context = color_button_yellow.get_style_context ();
        color_button_yellow_context.add_class (Granite.STYLE_CLASS_COLOR_BUTTON);
        color_button_yellow_context.add_class ("yellow");

        color_button_orange = new Gtk.CheckButton () {
            group = color_button_blue
        };

        unowned Gtk.StyleContext color_button_orange_context = color_button_orange.get_style_context ();
        color_button_orange_context.add_class (Granite.STYLE_CLASS_COLOR_BUTTON);
        color_button_orange_context.add_class ("orange");

        color_button_red = new Gtk.CheckButton () {
            group = color_button_blue
        };

        unowned Gtk.StyleContext color_button_red_context = color_button_red.get_style_context ();
        color_button_red_context.add_class (Granite.STYLE_CLASS_COLOR_BUTTON);
        color_button_red_context.add_class ("red");

        color_button_pink = new Gtk.CheckButton () {
            group = color_button_blue
        };

        unowned Gtk.StyleContext color_button_pink_context = color_button_pink.get_style_context ();
        color_button_pink_context.add_class (Granite.STYLE_CLASS_COLOR_BUTTON);
        color_button_pink_context.add_class ("pink");

        color_button_purple = new Gtk.CheckButton () {
            group = color_button_blue
        };

        unowned Gtk.StyleContext color_button_purple_context = color_button_purple.get_style_context ();
        color_button_purple_context.add_class (Granite.STYLE_CLASS_COLOR_BUTTON);
        color_button_purple_context.add_class ("purple");

        color_button_brown = new Gtk.CheckButton () {
            group = color_button_blue
        };

        unowned Gtk.StyleContext color_button_brown_context = color_button_brown.get_style_context ();
        color_button_brown_context.add_class (Granite.STYLE_CLASS_COLOR_BUTTON);
        color_button_brown_context.add_class ("brown");

        color_button_slate = new Gtk.CheckButton () {
            group = color_button_blue
        };

        unowned Gtk.StyleContext color_button_slate_context = color_button_slate.get_style_context ();
        color_button_slate_context.add_class (Granite.STYLE_CLASS_COLOR_BUTTON);
        color_button_slate_context.add_class ("slate");

        color_button_none = new Gtk.CheckButton () {
            group = color_button_blue
        };

        var color_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_top = 12,
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12,
        };
        color_box.append (color_button_blue);
        color_box.append (color_button_mint);
        color_box.append (color_button_green);
        color_box.append (color_button_yellow);
        color_box.append (color_button_orange);
        color_box.append (color_button_red);
        color_box.append (color_button_pink);
        color_box.append (color_button_purple);
        color_box.append (color_button_brown);
        color_box.append (color_button_slate);

        var show_completed_button = new Granite.SwitchModelButton (_("Show Completed")) {
            margin_top = 3
        };

        var delete_list_accel_label = new Granite.AccelLabel.from_action_name (
            _("Delete List…"),
            MainWindow.ACTION_PREFIX + MainWindow.ACTION_DELETE_SELECTED_LIST
        );

        var delete_list_menuitem = new Gtk.Button ();
        delete_list_menuitem.action_name = delete_list_accel_label.action_name;
        delete_list_menuitem.get_child ().destroy ();
        delete_list_menuitem.child = delete_list_accel_label;
        delete_list_menuitem.get_style_context ().add_class (Granite.STYLE_CLASS_DESTRUCTIVE_ACTION);

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_top = 3,
            margin_bottom = 3
        };
        box.append (color_box);
        box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        box.append (show_completed_button);
        box.append (delete_list_menuitem);

        child = box;

        color_button_red.toggled.connect (() => {
            if (color_button_red.active) {
                update_task_list_color (source, "#c6262e");
            }
        });

        color_button_orange.toggled.connect (() => {
            if (color_button_orange.active) {
                update_task_list_color (source, "#f37329");
            }
        });

        color_button_yellow.toggled.connect (() => {
            if (color_button_yellow.active) {
                update_task_list_color (source, "#e6a92a");
            }
        });

        color_button_mint.toggled.connect (() => {
            if (color_button_mint.active) {
                update_task_list_color (source, "#0e9a83");
            }
        });

        color_button_green.toggled.connect (() => {
            if (color_button_green.active) {
                update_task_list_color (source, "#68b723");
            }
        });

        color_button_blue.toggled.connect (() => {
            if (color_button_blue.active) {
                update_task_list_color (source, "#3689e6");
            }
        });

        color_button_purple.toggled.connect (() => {
            if (color_button_purple.active) {
                update_task_list_color (source, "#a56de2");
            }
        });

        color_button_pink.toggled.connect (() => {
            if (color_button_pink.active) {
                update_task_list_color (source, "#de3e80");
            }
        });

        color_button_brown.toggled.connect (() => {
            if (color_button_brown.active) {
                update_task_list_color (source, "#8a715e");
            }
        });

        color_button_slate.toggled.connect (() => {
            if (color_button_slate.active) {
                update_task_list_color (source, "#667885");
            }
        });

        notify["source"].connect (() => {
            select_task_list_color (get_task_list_color (source));
        });

        Application.settings.bind ("show-completed", show_completed_button, "active", GLib.SettingsBindFlags.DEFAULT);
    }

    private void select_task_list_color (string color) {
        debug ("Select task list color: %s", color);

        switch (color.down ()) {
            case "#c6262e":
                color_button_red.active = true;
                break;
            case "#f37329":
                color_button_orange.active = true;
                break;
            case "#e6a92a":
                color_button_yellow.active = true;
                break;
            case "#68b723":
                color_button_green.active = true;
                break;
            case "#0e9a83":
                color_button_mint.active = true;
                break;
            case "#3689e6":
                color_button_blue.active = true;
                break;
            case "#a56de2":
                color_button_purple.active = true;
                break;
            case "#de3e80":
                color_button_pink.active = true;
                break;
            case "#8a715e":
                color_button_brown.active = true;
                break;
            case "#667885":
                color_button_slate.active = true;
                break;
            default:
                color_button_none.active = true;
                break;
        }
    }

    private string get_task_list_color (E.Source source) {
        if (source.has_extension (E.SOURCE_EXTENSION_TASK_LIST)) {
            var task_list = (E.SourceTaskList) source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);
            return task_list.dup_color ();
        }
        return "";
    }

    private void update_task_list_color (E.Source source, string color) {
        var old_color = get_task_list_color (source);
        if (old_color == color) {
            return;
        }

        Tasks.Application.model.update_task_list_color.begin (source, color, (obj, res) => {
            try {
                Tasks.Application.model.update_task_list_color.end (res);
            } catch (Error e) {
                select_task_list_color (old_color);
                dialog_update_task_list_color_error (e);
            }
        });
    }

    private void dialog_update_task_list_color_error (Error e) {
        var error_dialog = new Granite.MessageDialog (
            _("Could not change the task list color"),
            _("The task list registry may be unavailable or write-protected."),
            new ThemedIcon ("dialog-error"),
            Gtk.ButtonsType.CLOSE
        );
        error_dialog.show_error_details (e.message);
        error_dialog.present ();
        error_dialog.response.connect (() => {
            error_dialog.destroy ();
        });
    }
}
