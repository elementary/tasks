/*
 * Copyright 2016-2023 elementary, Inc. (https://elementary.io)
 * Copyright 2016 Corentin Noël <corentin@elementary.io>
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Tasks.Widgets.EditableLabel : Gtk.Widget {
    public signal void changed ();

    private Gtk.Label title;
    private Gtk.Entry entry;
    private Gtk.Stack stack;
    private Gtk.Box box;

    public string text { get; set; default = ""; }

    public bool editing {
        get { return stack.visible_child == entry; }
        set {
            if (value) {
                entry.text = text;
                stack.set_visible_child (entry);
                entry.grab_focus ();
            } else {
                if (entry.text.strip () != "" && text != entry.text) {
                    text = entry.text;
                    changed ();
                }

                stack.set_visible_child (box);
            }
        }
    }

    class construct {
        set_layout_manager_type (typeof (Gtk.BinLayout));
        set_css_name ("editable-label");
    }

    construct {
        valign = Gtk.Align.CENTER;

        title = new Gtk.Label ("") {
            ellipsize = Pango.EllipsizeMode.END,
            xalign = 0
        };

        var edit_button = new Gtk.Button () {
            icon_name = "edit-symbolic",
            tooltip_text = _("Edit…")
        };
        edit_button.add_css_class (Granite.STYLE_CLASS_FLAT);

        var button_revealer = new Gtk.Revealer () {
            valign = Gtk.Align.CENTER,
            transition_type = Gtk.RevealerTransitionType.CROSSFADE,
            child = edit_button
        };

        box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            valign = Gtk.Align.CENTER
        };
        box.append (title);
        box.append (button_revealer);

        entry = new Gtk.Entry () {
            hexpand = true,
        };

        stack = new Gtk.Stack () {
            hhomogeneous = false,
            transition_type = Gtk.StackTransitionType.CROSSFADE
        };
        stack.add_child (box);
        stack.add_child (entry);
        stack.set_parent (this); // ?

        bind_property ("text", title, "label");

        var motion_controller = new Gtk.EventControllerMotion ();
        add_controller (motion_controller);

        var press_controller = new Gtk.GestureClick ();
        add_controller (press_controller);

        motion_controller.enter.connect ((x, y) => {
            button_revealer.reveal_child = true;
        });

        motion_controller.leave.connect (() => {
            button_revealer.reveal_child = false;
        });

        press_controller.pressed.connect ((n_press, x, y) => {
            editing = true;
        });

        entry.activate.connect (() => {
            if (stack.visible_child == entry) {
                editing = false;
            }
        });


        var focus_controller = new Gtk.EventControllerFocus ();
        entry.add_controller (focus_controller);

        focus_controller.leave.connect (() => {
            if (stack.visible_child == entry) {
                editing = false;
            }
        });
    }

    public override bool grab_focus () {
        editing = true;

        return Gdk.EVENT_STOP;
    }

    ~EditableLabel () {
        get_last_child ().unparent ();
    }
}
