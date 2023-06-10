/*
 * Copyright 2016-2023 elementary, Inc. (https://elementary.io)
 * Copyright 2016 Corentin Noël <corentin@elementary.io>
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Tasks.Widgets.EditableLabel : Gtk.EventBox {
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
        events |= Gdk.EventMask.ENTER_NOTIFY_MASK;
        events |= Gdk.EventMask.LEAVE_NOTIFY_MASK;
        events |= Gdk.EventMask.BUTTON_PRESS_MASK;

        title = new Gtk.Label ("") {
            ellipsize = Pango.EllipsizeMode.END,
            xalign = 0
        };

        var edit_button = new Gtk.Button () {
            image = new Gtk.Image.from_icon_name ("edit-symbolic", Gtk.IconSize.MENU),
            tooltip_text = _("Edit…")
        };
        edit_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var button_revealer = new Gtk.Revealer () {
            valign = Gtk.Align.CENTER,
            transition_type = Gtk.RevealerTransitionType.CROSSFADE
        };
        button_revealer.add (edit_button);

        box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            valign = Gtk.Align.CENTER
        };
        box.add (title);
        box.add (button_revealer);

        entry = new Gtk.Entry () {
            hexpand = true
        };
        entry.get_style_context ().add_provider (label_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        stack = new Gtk.Stack () {
            hhomogeneous = false,
            transition_type = Gtk.StackTransitionType.CROSSFADE
        };
        stack.add (box);
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
