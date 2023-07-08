/*
 * Copyright 2019-2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Tasks.Widgets.ListSettingsPopover : Gtk.Popover {
    public E.Source source { get; construct set; }

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

    public ListSettingsPopover (E.Source source) {
        Object (source: source);
    }

    construct {
        autohide = true;

        color_button_blue = new Gtk.CheckButton () {
            css_classes = { Granite.STYLE_CLASS_COLOR_BUTTON, "blue" }
        };

        color_button_mint = new Gtk.CheckButton () {
            group = color_button_blue,
            css_classes = { Granite.STYLE_CLASS_COLOR_BUTTON, "mint" }
        };

        color_button_green = new Gtk.CheckButton () {
            group = color_button_blue,
            css_classes = { Granite.STYLE_CLASS_COLOR_BUTTON, "green" }
        };


        color_button_yellow = new Gtk.CheckButton () {
            group = color_button_blue,
            css_classes = { Granite.STYLE_CLASS_COLOR_BUTTON, "yellow" }
        };

        color_button_orange = new Gtk.CheckButton () {
            group = color_button_blue,
            css_classes = { Granite.STYLE_CLASS_COLOR_BUTTON, "orange" }
        };

        color_button_red = new Gtk.CheckButton () {
            group = color_button_blue,
            css_classes = { Granite.STYLE_CLASS_COLOR_BUTTON, "red" }
        };

        color_button_pink = new Gtk.CheckButton () {
            group = color_button_blue,
            css_classes = { Granite.STYLE_CLASS_COLOR_BUTTON, "pink" }
        };

        color_button_purple = new Gtk.CheckButton () {
            group = color_button_blue,
            css_classes = { Granite.STYLE_CLASS_COLOR_BUTTON, "purple" }
        };

        color_button_brown = new Gtk.CheckButton () {
            group = color_button_blue,
            css_classes = { Granite.STYLE_CLASS_COLOR_BUTTON, "brown" }
        };

        color_button_slate = new Gtk.CheckButton () {
            group = color_button_blue,
            css_classes = { Granite.STYLE_CLASS_COLOR_BUTTON, "slate" }
        };

        // FIXME: this CheckButton is unused
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

        var delete_list_menuitem = new Widgets.PopoverButton ();
        delete_list_menuitem.add_css_class (Granite.STYLE_CLASS_DESTRUCTIVE_ACTION);
        delete_list_menuitem.append (delete_list_accel_label);

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

        delete_list_menuitem.clicked.connect (() => {
            popdown ();

            unowned var main_window = (Gtk.ApplicationWindow) get_root ();
            ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_DELETE_SELECTED_LIST)).activate (null);
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
            unowned var task_list = (E.SourceTaskList) source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);
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
