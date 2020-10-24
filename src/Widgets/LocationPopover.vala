/*
* Copyright 2020 elementary, Inc. (https://elementary.io)
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

public class Tasks.LocationPopover : Tasks.EntryPopover<Geocode.Location?> {

    private GtkChamplain.Embed map = new GtkChamplain.Embed () {
        height_request = 120,
        width_request = 220
    };

    private Gtk.Frame map_frame = new Gtk.Frame (null);

    private Gtk.SearchEntry search_entry = new Gtk.SearchEntry () {
        placeholder_text = _("John Smith OR Example St."),
        hexpand = true
    };

    private Gtk.EntryCompletion search_entry_completion = new Gtk.EntryCompletion () {
        minimum_key_length = 3
    };

    private Granite.Widgets.ModeButton location_mode = new Granite.Widgets.ModeButton ();

    private Gtk.Grid grid = new Gtk.Grid () {
        margin = 6,
        row_spacing = 6,
        column_spacing = 6
    };

    construct {
        map.champlain_view.add_layer (
            new Champlain.MarkerLayer.full (Champlain.SelectionMode.SINGLE)
        );
        map_frame.add (map);

        location_mode.append_text (_("Arrival"));
        location_mode.append_text (_("Departure"));

        search_entry.set_completion (search_entry_completion);

        grid.attach (map_frame, 0, 0);
        grid.attach (search_entry, 0, 1);
        grid.attach (location_mode, 0, 2);
        grid.show_all ();

        popover.add (grid);
    }
}
