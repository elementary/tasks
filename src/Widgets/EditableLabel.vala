/*
 * Copyright 2016-2024 elementary, Inc. (https://elementary.io)
 * Copyright 2016 Corentin Noël <corentin@elementary.io>
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Tasks.Widgets.EditableLabel : Gtk.Widget {
    public signal void changed ();

    private Gtk.Label title;
    private Gtk.Entry entry;
    private Gtk.Stack stack;

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

                stack.set_visible_child (title);
            }
        }
    }

    class construct {
        set_layout_manager_type (typeof (Gtk.BinLayout));
        set_css_name ("editable-label");
    }

    construct {
        valign = CENTER;

        title = new Gtk.Label ("") {
            ellipsize = END,
            xalign = 0
        };

        entry = new Gtk.Entry () {
            hexpand = true,
        };

        stack = new Gtk.Stack () {
            hhomogeneous = false,
            transition_type = CROSSFADE
        };
        stack.add_child (title);
        stack.add_child (entry);
        stack.set_parent (this);

        bind_property ("text", title, "label");

        var motion_controller = new Gtk.EventControllerMotion () {
            propagation_phase = CAPTURE
        };

        var click_gesture = new Gtk.GestureClick ();

        add_controller (click_gesture);
        add_controller (motion_controller);

        motion_controller.enter.connect (() => {
            set_cursor (new Gdk.Cursor.from_name ("text", null));
        });

        motion_controller.leave.connect (() => {
            set_cursor (new Gdk.Cursor.from_name ("default", null));
        });

        click_gesture.released.connect (() => {
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

    ~EditableLabel () {
        get_first_child ().unparent ();
    }

    public override bool grab_focus () {
        editing = true;

        return Gdk.EVENT_STOP;
    }
}
