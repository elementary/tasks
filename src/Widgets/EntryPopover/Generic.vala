/*
 * Copyright 2021-2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public abstract class Tasks.Widgets.EntryPopover.Generic<T> : Gtk.Widget {
    public signal string? value_format (T value);
    public signal void value_changed (T value);

    public Gtk.Popover popover { get; private set; }
    public string? icon_name { get; construct; }
    public string placeholder { get; construct; }
    public T value { get; set; }

    private T value_on_popover_show;

    protected Generic (string placeholder, string? icon_name = null) {
        Object (
            icon_name: icon_name,
            placeholder: placeholder
        );
    }

    class construct {
        set_css_name ("entry-popover");
        set_layout_manager_type (typeof (Gtk.BinLayout));
    }

    construct {
        popover = new Gtk.Popover () {
            autohide = true
        };

        var label = new Gtk.Label (placeholder);

        var popover_button_box = new Gtk.Box (HORIZONTAL, 0);
        if (icon_name != null) {
            popover_button_box.append (new Gtk.Image.from_icon_name (icon_name));
        }
        popover_button_box.append (label);

        var popover_button = new Gtk.MenuButton () {
            child = popover_button_box,
            has_frame = false,
            popover = popover
        };

        label.mnemonic_widget = popover_button;

        var delete_button = new Gtk.Button.from_icon_name ("process-stop-symbolic") {
            tooltip_text = _("Remove")
        };
        delete_button.add_css_class ("delete-button");

        var delete_button_revealer = new Gtk.Revealer () {
            child = delete_button,
            transition_type = SLIDE_LEFT,
            reveal_child = false
        };

        var button_box = new Gtk.Box (HORIZONTAL, 0);
        button_box.add_css_class ("container");
        button_box.append (popover_button);
        button_box.append (delete_button_revealer);
        button_box.set_parent (this);

        delete_button.clicked.connect (() => {
            var value_has_changed = value != null;
            value = null;
            if (value_has_changed) {
                value_changed (value);
            }
        });

        popover_button.activate.connect (() => {
            if (delete_button_revealer.reveal_child) {
                delete_button_revealer.reveal_child = false;
            }
        });

        notify["value"].connect (() => {
            var value_formatted = value_format (value);
            if (value_formatted == null) {
                label.label = placeholder;

                if (delete_button_revealer.reveal_child) {
                    delete_button_revealer.reveal_child = false;
                }

            } else {
                label.label = value_formatted;
            }
        });

        var motion_controller = new Gtk.EventControllerMotion ();
        add_controller (motion_controller);

        motion_controller.enter.connect (() => {
            if (value_format (value) != null) {
                delete_button_revealer.reveal_child = true;
            }
        });

        motion_controller.leave.connect (() => {
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
    }

    ~Generic () {
        get_last_child ().unparent ();
    }
}
