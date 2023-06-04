/*
* Copyright (c) 2016 elementary LLC. (https://github.com/elementary/photos)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version.
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
* Authored by: Corentin Noël <corentin@elementary.io>
*/

public class Tasks.Widgets.EditableLabel : Gtk.Widget {
    public signal void changed ();

    private static Gtk.CssProvider label_provider;

    private Gtk.Label title;
    private Gtk.Entry entry;
    private Gtk.Stack stack;
    private Gtk.Box box;

    public string text { get; set; }

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

    static construct {
        label_provider = new Gtk.CssProvider ();
        label_provider.load_from_resource ("io/elementary/tasks/EditableLabel.css");
    }

    construct {
        unowned Gtk.StyleContext style_context = get_style_context ();
        style_context.add_class ("editable-label");
        style_context.add_provider (label_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        valign = Gtk.Align.CENTER;

        var motion_controller = new Gtk.EventControllerMotion ();
        add_controller (motion_controller);

        var press_controller = new Gtk.GestureClick ();
        add_controller (press_controller);

        var focus_controller = new Gtk.EventControllerFocus ();
        entry.add_controller (focus_controller);

        title = new Gtk.Label ("") {
            ellipsize = Pango.EllipsizeMode.END,
            xalign = 0
        };

        var edit_button = new Gtk.Button () {
            icon_name = "edit-symbolic",
            tooltip_text = _("Edit…")
        };
        edit_button.get_style_context ().add_class (Granite.STYLE_CLASS_FLAT);

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
            hexpand = true
        };
        entry.get_style_context ().add_provider (label_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        stack = new Gtk.Stack () {
            hhomogeneous = false,
            transition_type = Gtk.StackTransitionType.CROSSFADE
        };
        stack.add_child (box);
        stack.add_child (entry);

        stack.set_parent (this); // ?

        bind_property ("text", title, "label");

        motion_controller.enter.connect ((x, y) => {
            button_revealer.reveal_child = true;
        });

        motion_controller.leave.connect (() => {
            button_revealer.reveal_child = false;
        });

        press_controller.pressed.connect ((n_press, x, y) => {
            editing = true;
        });

        edit_button.clicked.connect (() => {
            editing = true;
        });

        entry.activate.connect (() => {
            if (stack.visible_child == entry) {
                editing = false;
            }
        });

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
}
