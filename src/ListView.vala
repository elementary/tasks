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

public class Reminders.ListView : Gtk.Grid {
    public E.Source? source { get; set; }

    construct {
        var label = new Gtk.Label ("");
        label.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);

        add (label);

        notify["source"].connect (() => {
            label.label = source.display_name;
            load_source (source);

            show_all ();
        });
    }

    private void load_source (E.Source source) {
        var iso_last = ECal.isodate_from_time_t ((time_t) new GLib.DateTime.now ().to_unix ());
        var iso_first = ECal.isodate_from_time_t ((time_t) new GLib.DateTime.now ().add_years (-1).to_unix ());
        var query = @"(occur-in-time-range? (make-time \"$iso_first\") (make-time \"$iso_last\"))";

        try {
            var client = (ECal.Client) ECal.Client.connect_sync (source, ECal.ClientSourceType.TASKS, -1, null);

            client.get_view.begin (query, null, (obj, results) => {
                try {
                    ECal.ClientView view;
                    client.get_view.end (results, out view);

                    view.objects_added.connect ((objects) => on_objects_added (source, client, objects));

                    view.start ();
                } catch (Error e) {
                    critical ("Error loading client-view from source '%s': %s", source.dup_display_name (), e.message);
                }
            });
        } catch (Error e) {
            critical (e.message);
        }
    }

    private void on_objects_added (E.Source source, ECal.Client client, SList<unowned ICal.Component> objects) {
        critical ("Object added!");
    }
}
