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
    private uint configure_id;
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
        listbox.set_header_func (header_update_func);
        listbox.set_sort_func (sort_function);

        var scrolledwindow = new Gtk.ScrolledWindow (null, null);
        scrolledwindow.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolledwindow.add (listbox);

        var listview = new Reminders.ListView ();

        var paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        paned.pack1 (scrolledwindow, false, false);
        paned.pack2 (listview, true, false);

        add (paned);

        load_sources.begin ();

        Reminders.Application.settings.bind ("pane-position", paned, "position", GLib.SettingsBindFlags.DEFAULT);

        listbox.row_selected.connect (() => {
            var source = ((Reminders.ListRow) listbox.get_selected_row ()).source;
            listview.source = source;
            Reminders.Application.settings.set_string ("selected-list", source.uid);
        });
    }

    private void header_update_func (Gtk.ListBoxRow lbrow, Gtk.ListBoxRow? lbbefore) {
        var row = (Reminders.ListRow) lbrow;
        if (lbbefore != null) {
            var before = (Reminders.ListRow) lbbefore;
            if (row.source.parent == before.source.parent) {
                return;
            }
        }

        var header_label = new Granite.HeaderLabel (row.source.parent);
        header_label.ellipsize = Pango.EllipsizeMode.MIDDLE;

        row.set_header (header_label);
    }

    [CCode (instance_pos = -1)]
    private int sort_function (Gtk.ListBoxRow lbrow, Gtk.ListBoxRow lbbefore) {
        var row = (Reminders.ListRow) lbrow;
        var before = (Reminders.ListRow) lbbefore;
        if (row.source.parent == before.source.parent) {
            return row.source.display_name.collate (before.source.display_name);
        } else {
            return row.source.parent.collate (before.source.parent);
        }
    }

    private async void load_sources () {
        try {
            var last_selected_list = Reminders.Application.settings.get_string ("selected-list");

            var registry = yield new E.SourceRegistry (null);
            registry.list_sources (E.SOURCE_EXTENSION_TASK_LIST).foreach ((source) => {
                var list_row = new Reminders.ListRow (source);
                listbox.add (list_row);

                if (last_selected_list == source.uid) {
                    listbox.select_row (list_row);
                }
            });

            listbox.show_all ();
        } catch (GLib.Error error) {
            critical (error.message);
        }
    }

    public override bool configure_event (Gdk.EventConfigure event) {
        if (configure_id != 0) {
            GLib.Source.remove (configure_id);
        }

        configure_id = Timeout.add (100, () => {
            configure_id = 0;

            if (is_maximized) {
                Reminders.Application.settings.set_boolean ("window-maximized", true);
            } else {
                Reminders.Application.settings.set_boolean ("window-maximized", false);

                Gdk.Rectangle rect;
                get_allocation (out rect);
                Reminders.Application.settings.set ("window-size", "(ii)", rect.width, rect.height);

                int root_x, root_y;
                get_position (out root_x, out root_y);
                Reminders.Application.settings.set ("window-position", "(ii)", root_x, root_y);
            }

            return false;
        });

        return base.configure_event (event);
    }
}
