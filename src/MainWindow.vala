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

public class Reminders.MainWindow : Gtk.ApplicationWindow {
    private Gtk.ListBox listbox;

    public MainWindow (Gtk.Application application) {
        Object (
            application: application,
            icon_name: "application-default-icon",
            title: _("Reminders")
        );
    }

    construct {
        listbox = new Gtk.ListBox ();

        var scrolledwindow = new Gtk.ScrolledWindow (null, null);
        scrolledwindow.add (listbox);

        var listview = new Reminders.ListView ();

        var paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        paned.pack1 (scrolledwindow, false, false);
        paned.pack2 (listview, true, false);

        add (paned);

        load_sources.begin ();

        listbox.row_selected.connect (() => {
            listview.source = ((Reminders.ListRow) listbox.get_selected_row ()).source;
        });
    }

    private async void load_sources () {
        try {
            var registry = yield new E.SourceRegistry (null);

            registry.list_sources (E.SOURCE_EXTENSION_TASK_LIST).foreach ((source) => {
                var list_row = new Reminders.ListRow (source);

                listbox.add (list_row);
            });

            listbox.show_all ();
        } catch (GLib.Error error) {
            critical (error.message);
        }
    }
}
