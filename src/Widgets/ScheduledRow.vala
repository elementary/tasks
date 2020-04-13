/*
* Copyright 2019 elementary, Inc. (https://elementary.io)
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
*
*/

public class Tasks.ScheduledRow : Gtk.ListBoxRow {

    private static Gtk.CssProvider listrow_provider;

    private Gtk.Image icon;
    private Gtk.Image status_image;
    private Gtk.Label display_name_label;
    private Gtk.Stack status_stack;
    private Gtk.Revealer revealer;

    static construct {
        listrow_provider = new Gtk.CssProvider ();
        listrow_provider.load_from_resource ("io/elementary/tasks/ScheduledRow.css");
    }

    construct {
        icon = new Gtk.Image.from_icon_name ("preferences-system-time-symbolic", Gtk.IconSize.MENU);

        display_name_label = new Gtk.Label (_("Scheduled"));
        display_name_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
        display_name_label.halign = Gtk.Align.START;
        display_name_label.hexpand = true;
        display_name_label.margin_end = 9;

        status_image = new Gtk.Image ();
        status_image.pixel_size = 16;
        status_image.get_style_context ().add_provider (listrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var spinner = new Gtk.Spinner ();
        spinner.active = true;
        spinner.tooltip_text = _("Connecting…");

        status_stack = new Gtk.Stack ();
        status_stack.add_named (status_image, "image");
        status_stack.add_named (spinner, "spinner");

        var grid = new Gtk.Grid ();
        grid.column_spacing = 3;
        grid.margin_start = 4;
        grid.margin_end = 6;
        grid.add (icon);
        grid.add (display_name_label);
        grid.add (status_stack);

        revealer = new Gtk.Revealer ();
        revealer.reveal_child = true;
        revealer.add (grid);

        add (revealer);
    }
}
