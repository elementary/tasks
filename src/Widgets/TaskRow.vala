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

public class Tasks.TaskRow : Gtk.ListBoxRow {
    public unowned ICal.Component component { get; construct; }

    public TaskRow (ICal.Component component) {
        Object (component: component);
    }

    construct {
        var check = new Gtk.CheckButton ();
        check.active = component.get_status () == ICal.PropertyStatus.COMPLETED;
        check.sensitive = false;

        var summary_label = new Gtk.Label (component.get_summary ());
        summary_label.wrap = true;
        summary_label.xalign = 0;

        var grid = new Gtk.Grid ();
        grid.margin = 3;
        grid.margin_start = grid.margin_end = 24;
        grid.column_spacing = 6;
        grid.add (check);
        grid.add (summary_label);

        var description = component.get_description ();
        if( description != null ) {
            description = description.replace("\r", "").replace("\n\n", "\n").strip();
            string[] lines = description.split ("\n");
             string stripped_description = lines[0].strip ();
             for (int i = 1; i < lines.length; i++) {
                 stripped_description += " " + lines[i].strip ();
             }

            if( description.length > 0 ){
                var description_label = new Gtk.Label (description);
                description_label.xalign = 0;
                description_label.lines = 1;
                description_label.ellipsize = Pango.EllipsizeMode.END;
                description_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

                grid.attach_next_to (description_label, summary_label, Gtk.PositionType.BOTTOM);
            }
        }

        add (grid);
    }
}
