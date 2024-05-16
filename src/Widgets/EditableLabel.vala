/*
 * Copyright 2016-2024 elementary, Inc. (https://elementary.io)
 * Copyright 2016 Corentin Noël <corentin@elementary.io>
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Tasks.Widgets.EditableLabel : Gtk.EventBox {
    public signal void changed ();

    private Gtk.Label title;
    private Gtk.Entry entry;
    private Gtk.Stack stack;

    private Gtk.EventControllerMotion motion_controller;
    private Gtk.GestureMultiPress click_gesture;

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
        set_css_name ("editable-label");
    }

    construct {
        valign = CENTER;

        title = new Gtk.Label ("") {
            ellipsize = END,
            xalign = 0
        };

        entry = new Gtk.Entry () {
            hexpand = true
        };

        stack = new Gtk.Stack () {
            hhomogeneous = false,
            transition_type = CROSSFADE
        };
        stack.add (title);
        stack.add (entry);

        add (stack);

        bind_property ("text", title, "label");

        motion_controller = new Gtk.EventControllerMotion (this) {
            propagation_phase = CAPTURE
        };

        click_gesture = new Gtk.GestureMultiPress (this);

        motion_controller.enter.connect (() => {
            get_window ().set_cursor (
                new Gdk.Cursor.from_name (Gdk.Display.get_default (), "text")
            );
        });

        motion_controller.leave.connect (() => {
            get_window ().set_cursor (
                new Gdk.Cursor.from_name (Gdk.Display.get_default (), "default")
            );
        });

        click_gesture.released.connect (() => {
            editing = true;
        });

        entry.activate.connect (() => {
            if (stack.visible_child == entry) {
                editing = false;
            }
        });

        entry.focus_out_event.connect ((event) => {
            if (stack.visible_child == entry) {
                editing = false;
            }

            return Gdk.EVENT_PROPAGATE;
        });
    }

    public override void grab_focus () {
        editing = true;
    }
}
