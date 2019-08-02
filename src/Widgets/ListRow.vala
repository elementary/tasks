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

public class Reminders.ListRow : Gtk.ListBoxRow {
    public E.Source source { get; construct; }

    public ListRow (E.Source source) {
        Object (source: source);
    }

    construct {
        var image = new Gtk.Image.from_icon_name ("checkbox-checked-symbolic", Gtk.IconSize.MENU);
        image.get_style_context ().add_class (Granite.STYLE_CLASS_ACCENT);

        Reminders.Application.set_task_color (source, image);

        var label = new Gtk.Label (source.display_name);
        label.halign = Gtk.Align.START;

        var grid = new Gtk.Grid ();
        grid.column_spacing = 6;
        grid.margin_start = 12;
        grid.margin_end = 6;
        grid.add (image);
        grid.add (label);

        add (grid);
    }
}
