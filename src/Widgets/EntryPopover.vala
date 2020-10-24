/*
* Copyright 2020 elementary, Inc. (https://elementary.io)
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
*/

public abstract class Tasks.EntryPopover<T> : Gtk.EventBox {

    public string? placeholder { get; set; }

    public Gtk.Image image {
        get { return (Gtk.Image) popover_button.image; }
        set { popover_button.image = value; }
    }

    public Gtk.Popover popover {
        get { return popover_button.popover; }
    }

    public Gtk.ArrowType direction {
        get { return popover_button.direction; }
        set { popover_button.direction = value; }
    }

    public T value { get; set; }
    public signal void value_changed (T value);
    public signal string? value_format (T value);

    private Gtk.Box button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
        baseline_position = Gtk.BaselinePosition.CENTER,
        homogeneous = false
    };

    private Gtk.MenuButton popover_button = new Gtk.MenuButton () {
        always_show_image = true,
        use_popover = true
    };

    private Gtk.Button delete_button = new Gtk.Button.from_icon_name ("window-close", Gtk.IconSize.BUTTON) {
        always_show_image = true,
        tooltip_text = _("Remove")
    };

    private Gtk.Revealer delete_button_revealer = new Gtk.Revealer () {
        transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT,
        reveal_child = false
    };

    construct {
        events |= Gdk.EventMask.ENTER_NOTIFY_MASK
            | Gdk.EventMask.LEAVE_NOTIFY_MASK;

        popover_button.label = (placeholder != null && placeholder.length > 0 ? placeholder : _("Set Value"));
        popover_button.popover = new Gtk.Popover (popover_button);

        delete_button_revealer.add (delete_button);
        button_box.add (popover_button);
        button_box.add (delete_button_revealer);
        add (button_box);

        popover_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        delete_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        delete_button.clicked.connect (() => {
            value = null;
        });

        popover_button.clicked.connect (() => {
            if (delete_button_revealer.reveal_child) {
                delete_button_revealer.reveal_child = false;
            }
        });

        notify["placeholder"].connect (() => {
            if (value_format (value) == null) {
                popover_button.label = (placeholder != null && placeholder.length > 0 ? placeholder : _("Set Value"));
            }
        });

        notify["value"].connect (() => {
            var value_formatted = value_format (value);
            if (value_formatted == null) {
                popover_button.label = (placeholder != null && placeholder.length > 0 ? placeholder : _("Set Value"));

                if (delete_button_revealer.reveal_child) {
                    Timeout.add (150, () => {
                        delete_button_revealer.reveal_child = false;
                        return GLib.Source.REMOVE;
                    });
                }

            } else {
                popover_button.label = value_formatted;
            }
            value_changed (value);
        });

        enter_notify_event.connect (() => {
            if (value_format (value) != null) {
                delete_button_revealer.reveal_child = true;
            }
        });

        leave_notify_event.connect (() => {
            if (delete_button_revealer.reveal_child) {
                delete_button_revealer.reveal_child = false;
            }
        });
    }
}
