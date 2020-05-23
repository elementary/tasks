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

    construct {
        var icon = new Gtk.Image.from_icon_name ("preferences-system-time-symbolic", Gtk.IconSize.MENU);

        var display_name_label = new Gtk.Label (_("Scheduled"));
        display_name_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
        display_name_label.halign = Gtk.Align.START;
        display_name_label.hexpand = true;
        display_name_label.margin_end = 9;

        var grid = new Gtk.Grid ();
        grid.column_spacing = 3;
        grid.margin_start = 10;
        grid.margin_end = 6;
        grid.add (icon);
        grid.add (display_name_label);

        add (grid);
    }
}
