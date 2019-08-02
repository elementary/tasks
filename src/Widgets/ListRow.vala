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

        set_event_calendar_color (source, image);

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

    private Gee.HashMap<string, Gtk.CssProvider>? providers;
    private void set_event_calendar_color (E.Source source, Gtk.Widget widget) {
        if (providers == null) {
            providers = new Gee.HashMap<string, Gtk.CssProvider> ();
        }
        var task_list = (E.SourceTaskList?) source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);
        var color = task_list.dup_color ();
        if (!providers.has_key (color)) {
            string style = """
                @define-color colorAccent %s;
            """.printf (color);

            try {
                var style_provider = new Gtk.CssProvider ();
                style_provider.load_from_data (style, style.length);

                providers[color] = style_provider;
            } catch (Error e) {
                critical ("Unable to set calendar color: %s", e.message);
            }
        }

        unowned Gtk.StyleContext style_context = widget.get_style_context ();
        style_context.add_provider (providers[color], Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }
}
