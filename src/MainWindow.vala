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

public class Tasks.MainWindow : Gtk.ApplicationWindow {
    private uint configure_id;
    private Gtk.ListBox listbox;

    private E.SourceRegistry registry;

    public MainWindow (Gtk.Application application) {
        Object (
            application: application,
            icon_name: "io.elementary.tasks",
            title: _("Tasks")
        );
    }

    construct {
        var header_provider = new Gtk.CssProvider ();
        header_provider.load_from_resource ("io/elementary/tasks/HeaderBar.css");

        var sidebar_header = new Gtk.HeaderBar ();
        sidebar_header.decoration_layout = "close:";
        sidebar_header.has_subtitle = false;
        sidebar_header.show_close_button = true;

        unowned Gtk.StyleContext sidebar_header_context = sidebar_header.get_style_context ();
        sidebar_header_context.add_class ("sidebar-header");
        sidebar_header_context.add_class ("titlebar");
        sidebar_header_context.add_class ("default-decoration");
        sidebar_header_context.add_class (Gtk.STYLE_CLASS_FLAT);
        sidebar_header_context.add_provider (header_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var listview_header = new Gtk.HeaderBar ();
        listview_header.has_subtitle = false;
        listview_header.decoration_layout = ":maximize";
        listview_header.show_close_button = true;

        unowned Gtk.StyleContext listview_header_context = listview_header.get_style_context ();
        listview_header_context.add_class ("listview-header");
        listview_header_context.add_class ("titlebar");
        listview_header_context.add_class ("default-decoration");
        listview_header_context.add_class (Gtk.STYLE_CLASS_FLAT);
        listview_header_context.add_provider (header_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var header_paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        header_paned.pack1 (sidebar_header, false, false);
        header_paned.pack2 (listview_header, true, false);

        listbox = new Gtk.ListBox ();
        listbox.set_header_func (header_update_func);
        listbox.set_sort_func (sort_function);

        var scrolledwindow = new Gtk.ScrolledWindow (null, null);
        scrolledwindow.expand = true;
        scrolledwindow.margin_bottom = 3;
        scrolledwindow.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolledwindow.add (listbox);

        var sidebar_provider = new Gtk.CssProvider ();
        sidebar_provider.load_from_resource ("io/elementary/tasks/Sidebar.css");

        var add_tasklist_button = new Gtk.Button.from_icon_name ("list-add-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        add_tasklist_button.tooltip_text = _("Add Task List");
        add_tasklist_button.get_style_context ().add_provider (sidebar_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var actionbar = new Gtk.ActionBar ();
        actionbar.add (add_tasklist_button);

        unowned Gtk.StyleContext actionbar_style_context = actionbar.get_style_context ();
        actionbar_style_context.add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
        actionbar_style_context.add_provider (sidebar_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var sidebar = new Gtk.Grid ();
        sidebar.attach (scrolledwindow, 0, 0);
        sidebar.attach (actionbar, 0, 1);

        unowned Gtk.StyleContext sidebar_style_context = sidebar.get_style_context ();
        sidebar_style_context.add_class (Gtk.STYLE_CLASS_SIDEBAR);
        sidebar_style_context.add_provider (sidebar_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var listview = new Tasks.ListView ();

        var paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        paned.pack1 (sidebar, false, false);
        paned.pack2 (listview, true, false);

        set_titlebar (header_paned);
        add (paned);

        // This must come after setting header_paned as the titlebar
        unowned Gtk.StyleContext header_paned_context = header_paned.get_style_context ();
        header_paned_context.remove_class ("titlebar");
        header_paned_context.add_provider (header_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        get_style_context ().add_class ("rounded");

        load_sources.begin ();

        Tasks.Application.settings.bind ("pane-position", header_paned, "position", GLib.SettingsBindFlags.DEFAULT);
        Tasks.Application.settings.bind ("pane-position", paned, "position", GLib.SettingsBindFlags.DEFAULT);

        listbox.row_selected.connect (() => {
            var source = ((Tasks.ListRow) listbox.get_selected_row ()).source;
            listview.source = source;
            Tasks.Application.settings.set_string ("selected-list", source.uid);
        });
    }

    private void header_update_func (Gtk.ListBoxRow lbrow, Gtk.ListBoxRow? lbbefore) {
        var row = (Tasks.ListRow) lbrow;
        if (lbbefore != null) {
            var before = (Tasks.ListRow) lbbefore;
            if (row.source.parent == before.source.parent) {
                return;
            }
        }

        string display_name;
        var ancestor = registry.find_extension (row.source, E.SOURCE_EXTENSION_COLLECTION);
        if (ancestor != null) {
            display_name = ancestor.display_name;
        } else {
            display_name = ((E.SourceTaskList?) row.source.get_extension (E.SOURCE_EXTENSION_TASK_LIST)).backend_name;
        }

        var header_label = new Granite.HeaderLabel (display_name);
        header_label.ellipsize = Pango.EllipsizeMode.MIDDLE;

        row.set_header (header_label);
    }

    [CCode (instance_pos = -1)]
    private int sort_function (Gtk.ListBoxRow lbrow, Gtk.ListBoxRow lbbefore) {
        var row = (Tasks.ListRow) lbrow;
        var before = (Tasks.ListRow) lbbefore;
        if (row.source.parent == before.source.parent) {
            return row.source.display_name.collate (before.source.display_name);
        } else {
            return row.source.parent.collate (before.source.parent);
        }
    }

    private async void load_sources () {
        try {
            var last_selected_list = Tasks.Application.settings.get_string ("selected-list");

            registry = yield new E.SourceRegistry (null);
            registry.list_sources (E.SOURCE_EXTENSION_TASK_LIST).foreach ((source) => {
                var list_row = new Tasks.ListRow (source);
                listbox.add (list_row);

                if (last_selected_list == "" && registry.default_task_list == source) {
                    listbox.select_row (list_row);
                } else if (last_selected_list == source.uid) {
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
                Tasks.Application.settings.set_boolean ("window-maximized", true);
            } else {
                Tasks.Application.settings.set_boolean ("window-maximized", false);

                Gdk.Rectangle rect;
                get_allocation (out rect);
                Tasks.Application.settings.set ("window-size", "(ii)", rect.width, rect.height);

                int root_x, root_y;
                get_position (out root_x, out root_y);
                Tasks.Application.settings.set ("window-position", "(ii)", root_x, root_y);
            }

            return false;
        });

        return base.configure_event (event);
    }
}
