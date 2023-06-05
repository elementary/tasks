/*
* Copyright 2021-2023 elementary, Inc. (https://elementary.io)
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

public abstract class Tasks.Widgets.EntryPopover.Generic<T> : Gtk.Widget {
    public signal string? value_format (T value);
    public signal void value_changed (T value);

    public Gtk.Popover popover { get; private set; }
    public string? icon_name { get; construct; }
    public string placeholder { get; construct; }
    public T value { get; set; }

    private Gtk.MenuButton popover_button;
    private static Gtk.CssProvider style_provider;
    private T value_on_popover_show;

    protected Generic (string placeholder, string? icon_name = null) {
        Object (
            icon_name: icon_name,
            placeholder: placeholder
        );
    }

    class construct {
        set_css_name ("entry-popover");
    }

    static construct {
        set_layout_manager_type (typeof (Gtk.BinLayout));

        style_provider = new Gtk.CssProvider ();
        style_provider.load_from_resource ("io/elementary/tasks/EntryPopover.css");
    }

    construct { 
        popover = new Gtk.Popover () {
            child = popover_button
        };

        var popover_button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        if (icon_name != null) {
            popover_button_box.append (new Gtk.Image.from_icon_name (icon_name));
        }
        popover_button_box.append (new Gtk.Label (placeholder));
        
        popover_button = new Gtk.MenuButton () {
            popover = popover,
            child = popover_button_box,
            css_classes = { Granite.STYLE_CLASS_FLAT }
        };
        popover_button.get_style_context ().add_provider (style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var delete_button = new Gtk.Button.from_icon_name ("process-stop-symbolic") {
            tooltip_text = _("Remove"),
            css_classes = { Granite.STYLE_CLASS_FLAT }
        };
        delete_button.get_style_context ().add_provider (style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var delete_button_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT,
            reveal_child = false,
            child = delete_button
        };

        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        button_box.get_style_context ().add_provider (style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        button_box.append (popover_button);
        button_box.append (delete_button_revealer);
        button_box.set_parent (this);

        popover_button.activate.connect (() => {
            if (delete_button_revealer.reveal_child) {
                delete_button_revealer.reveal_child = false;
            }
        });

        popover.show.connect (() => {
            GLib.Idle.add (() => {
                value_on_popover_show = value;
                return GLib.Source.REMOVE;
            });
        });

        popover.closed.connect (() => {
            GLib.Idle.add (() => {
                if (value != value_on_popover_show) {
                    value_changed (value);
                }
                return GLib.Source.REMOVE;
            });
        });

        delete_button.clicked.connect (() => {
            var value_has_changed = value != null;
            value = null;
            if (value_has_changed) {
                value_changed (value);
            }
        });

        notify["value"].connect (() => {
            var value_formatted = value_format (value);
            if (value_formatted == null) {
                popover_button.label = placeholder;

                if (delete_button_revealer.reveal_child) {
                    delete_button_revealer.reveal_child = false;
                }

            } else {
                popover_button.label = value_formatted;
            }
        });

        var motion_controller = new Gtk.EventControllerMotion ();
        add_controller (motion_controller);

        motion_controller.enter.connect ((x, y) => {
            if (value_format (value) != null) {
                delete_button_revealer.reveal_child = true;
            }
        });

        motion_controller.leave.connect (() => {
            if (delete_button_revealer.reveal_child) {
                delete_button_revealer.reveal_child = false;
            }
        });
    }

    ~Generic () {
        get_last_child ().unparent ();
    }
}
