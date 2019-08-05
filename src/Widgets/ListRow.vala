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

public class Tasks.ListRow : Gtk.ListBoxRow {
    public E.Source source { get; construct; }

    private static Gtk.CssProvider color_provider;

    public ListRow (E.Source source) {
        Object (source: source);
    }

    static construct {
        color_provider = new Gtk.CssProvider ();
        color_provider.load_from_resource ("io/elementary/tasks/ListRow.css");
    }

    construct {
        var source_color = new Gtk.Grid ();
        source_color.valign = Gtk.Align.CENTER;

        unowned Gtk.StyleContext source_color_context = source_color.get_style_context ();
        source_color_context.add_class ("source-color");
        source_color_context.add_provider (color_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        Tasks.Application.set_task_color (source, source_color);

        var label = new Gtk.Label (source.display_name);
        label.halign = Gtk.Align.START;

        var grid = new Gtk.Grid ();
        grid.column_spacing = 3;
        grid.margin_start = 12;
        grid.margin_end = 6;
        grid.add (source_color);
        grid.add (label);

        add (grid);
    }
}
