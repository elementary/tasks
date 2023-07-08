/*
 * Copyright 2019-2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Tasks.Widgets.ScheduledRow : Gtk.ListBoxRow {

    construct {
        var icon = new Gtk.Image.from_icon_name ("appointment");

        var display_name_label = new Gtk.Label (_("Scheduled")) {
            ellipsize = Pango.EllipsizeMode.MIDDLE,
            halign = Gtk.Align.START,
            hexpand = true,
            margin_end = 9
        };

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_start = 12,
            margin_end = 6
        };
<<<<<<< HEAD
        box.append (icon);
        box.append (display_name_label);

        child = box;
=======
        box.add (icon);
        box.add (display_name_label);

        add (box);
>>>>>>> master
    }
}
