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

public class Tasks.EditableLabel : Gtk.EventBox {
    public signal void changed ();

    private static Gtk.CssProvider label_provider;

    private Gtk.Label title;
    private Gtk.Entry entry;
    private Gtk.Stack stack;
    private Gtk.Grid grid;

    public string text { get; set; }

    public bool editing {
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

                stack.set_visible_child (grid);
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
        events |= Gdk.EventMask.ENTER_NOTIFY_MASK;
        events |= Gdk.EventMask.LEAVE_NOTIFY_MASK;
        events |= Gdk.EventMask.BUTTON_PRESS_MASK;

        title = new Gtk.Label ("");
        title.ellipsize = Pango.EllipsizeMode.END;
        title.xalign = 0;

        var edit_button = new Gtk.Button ();
        edit_button.image = new Gtk.Image.from_icon_name ("edit-symbolic", Gtk.IconSize.MENU);
        edit_button.tooltip_text = _("Edit…");
        edit_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var button_revealer = new Gtk.Revealer ();
        button_revealer.valign = Gtk.Align.CENTER;
        button_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        button_revealer.add (edit_button);

        grid = new Gtk.Grid ();
        grid.valign = Gtk.Align.CENTER;
        grid.column_spacing = 12;
        grid.add (title);
        grid.add (button_revealer);

        entry = new Gtk.Entry ();
        entry.get_style_context ().add_provider (label_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        entry.hexpand = true;

        stack = new Gtk.Stack ();
        stack.hhomogeneous = false;
        stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
        stack.add (grid);
        stack.add (entry);

        add (stack);

        bind_property ("text", title, "label");

        enter_notify_event.connect ((event) => {
            if (event.detail != Gdk.NotifyType.INFERIOR) {
                button_revealer.reveal_child = true;
            }

            return Gdk.EVENT_PROPAGATE;
        });

        leave_notify_event.connect ((event) => {
            if (event.detail != Gdk.NotifyType.INFERIOR) {
                button_revealer.reveal_child = false;
            }

            return Gdk.EVENT_PROPAGATE;
        });

        button_press_event.connect ((event) => {
            editing = true;
            return Gdk.EVENT_PROPAGATE;
        });

        edit_button.clicked.connect (() => {
            editing = true;
        });

        entry.activate.connect (() => {
            if (stack.visible_child == entry) {
                editing = false;
            }
        });

        grab_focus.connect (() => {
            editing = true;
        });

        entry.focus_out_event.connect ((event) => {
            if (stack.visible_child == entry) {
                editing = false;
            }
            return Gdk.EVENT_PROPAGATE;
        });
    }
}
