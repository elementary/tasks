/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

class Tasks.PopoverMenuitem : Gtk.Button {
    public string text {
        set {
            child = new Granite.AccelLabel (value) {
                action_name = this.action_name
            };

            update_property (Gtk.AccessibleProperty.LABEL, value, -1);
        }
    }

    class construct {
        set_css_name ("modelbutton");
    }

    construct {
        accessible_role = MENU_ITEM;

        clicked.connect (() => {
            var popover = (Gtk.Popover) get_ancestor (typeof (Gtk.Popover));
            if (popover != null) {
                popover.popdown ();
            }
        });
    }
}
