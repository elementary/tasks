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
    public const string ACTION_PREFIX = "win.";
    public const string ACTION_DELETE_SELECTED_LIST = "action-delete-selected-list";

    private const ActionEntry[] ACTION_ENTRIES = {
        { ACTION_DELETE_SELECTED_LIST, action_delete_selected_list }
    };

    private static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

    private uint configure_id;
    private Gtk.ListBox listbox;
    private Gee.HashMap<E.Source, Tasks.SourceRow>? source_rows;
    private Tasks.ListView listview;
    private Gee.Collection<ECal.ClientView> taskviews;

    public MainWindow (Gtk.Application application) {
        Object (
            application: application,
            icon_name: "io.elementary.tasks",
            title: _("Tasks")
        );
    }

    static construct {
        action_accelerators[ACTION_DELETE_SELECTED_LIST] = "<Control>BackSpace";
        action_accelerators[ACTION_DELETE_SELECTED_LIST] = "Delete";
    }

    construct {
        add_action_entries (ACTION_ENTRIES, this);

        foreach (var action in action_accelerators.get_keys ()) {
            ((Gtk.Application) GLib.Application.get_default ()).set_accels_for_action (ACTION_PREFIX + action, action_accelerators[action].to_array ());  // vala-lint=line-length
        }

        taskviews = new Gee.ArrayList<ECal.ClientView> ((Gee.EqualDataFunc<ECal.ClientView>?) direct_equal);

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
        listbox.set_sort_func (sort_function);

        var scheduled_row = new Tasks.ScheduledRow ();
        listbox.add (scheduled_row);

        var scrolledwindow = new Gtk.ScrolledWindow (null, null);
        scrolledwindow.expand = true;
        scrolledwindow.margin_bottom = 3;
        scrolledwindow.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolledwindow.add (listbox);

        var sidebar = new Gtk.Grid ();
        sidebar.add (scrolledwindow);

        var sidebar_provider = new Gtk.CssProvider ();
        sidebar_provider.load_from_resource ("io/elementary/tasks/Sidebar.css");

        unowned Gtk.StyleContext sidebar_style_context = sidebar.get_style_context ();
        sidebar_style_context.add_class (Gtk.STYLE_CLASS_SIDEBAR);
        sidebar_style_context.add_provider (sidebar_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        listview = new Tasks.ListView ();

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

        Tasks.Application.settings.bind ("pane-position", header_paned, "position", GLib.SettingsBindFlags.DEFAULT);
        Tasks.Application.settings.bind ("pane-position", paned, "position", GLib.SettingsBindFlags.DEFAULT);

        Tasks.Application.task_store.source_added.connect (add_source);
        Tasks.Application.task_store.source_changed.connect (update_source);
        Tasks.Application.task_store.source_removed.connect (remove_source);

        Tasks.Application.task_store.components_added.connect (components_added);
        Tasks.Application.task_store.components_modified.connect (components_modified);
        Tasks.Application.task_store.components_removed.connect (components_removed);

        listbox.set_header_func (header_update_func);
        listbox.row_selected.connect ((row) => {
            lock (taskviews) {
                taskviews.foreach ((taskview) => {
                    try {
                        Tasks.Application.task_store.remove_view (taskview);
                    } catch (Error e) {
                        warning (e.message);
                    }
                });
                taskviews.clear ();
            }

            if (row != null) {
                if (row is Tasks.SourceRow) {
                    var source = ((Tasks.SourceRow) row).source;
                    Tasks.Application.settings.set_string ("selected-list", source.uid);

                    listview.source = source;
                    try {
                        var view = Tasks.Application.task_store.add_view (source, "(contains? 'any' '')");
                        taskviews.add (view);
                    } catch (Error e) {
                        warning (e.message);
                    }

                    ((SimpleAction) lookup_action (ACTION_DELETE_SELECTED_LIST)).set_enabled (source.removable);

                } else if (row is Tasks.ScheduledRow) {
                    listview.source = null;
                    Tasks.Application.settings.set_string ("selected-list", "scheduled");

                    var sources = Tasks.Application.task_store.list_sources ();
                    var query = "AND (NOT is-completed?) (OR (has-start?) (has-alarms?))";

                    sources.foreach ((source) => {
                        if (Tasks.Application.task_store.is_source_enabled (source)) {
                            try {
                                var view = Tasks.Application.task_store.add_view (source, query);
                                taskviews.add (view);
                            } catch (Error e) {
                                warning (e.message);
                            }
                        }
                    });

                    ((SimpleAction) lookup_action (ACTION_DELETE_SELECTED_LIST)).set_enabled (false);
                }

            } else {
                ((SimpleAction) lookup_action (ACTION_DELETE_SELECTED_LIST)).set_enabled (false);
                var first_row = listbox.get_row_at_index (0);
                if (first_row != null) {
                    listbox.select_row (first_row);
                } else {
                    listview.source = null;
                }
            }
        });

        if (Application.settings.get_string ("selected-list") == "scheduled") {
            listbox.select_row (scheduled_row);
        }
    }

    private void action_delete_selected_list () {
        var list_row = ((Tasks.SourceRow) listbox.get_selected_row ());
        var source = list_row.source;
        if (source.removable) {
            source.remove.begin (null);
        } else {
            Gdk.beep ();
        }
    }

    private void header_update_func (Gtk.ListBoxRow lbrow, Gtk.ListBoxRow? lbbefore) {
        if (!(lbrow is Tasks.SourceRow)) {
            return;
        }
        var row = (Tasks.SourceRow) lbrow;
        if (lbbefore != null && lbbefore is Tasks.SourceRow) {
            var before = (Tasks.SourceRow) lbbefore;
            if (row.source.parent == before.source.parent) {
                return;
            }
        }

        var display_name = Tasks.Application.task_store.get_source_ancestor_display_name (row.source);
        var header_label = new Granite.HeaderLabel (display_name);
        header_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
        header_label.margin_start = 6;

        row.set_header (header_label);
    }

    [CCode (instance_pos = -1)]
    private int sort_function (Gtk.ListBoxRow lbrow, Gtk.ListBoxRow lbbefore) {
        if (!(lbrow is Tasks.SourceRow)) {
            return -1;
        }
        var row = (Tasks.SourceRow) lbrow;
        var before = (Tasks.SourceRow) lbbefore;
        if (row.source.parent == before.source.parent) {
            return row.source.display_name.collate (before.source.display_name);
        } else {
            return row.source.parent.collate (before.source.parent);
        }
    }

    private void add_source (E.Source source) {
        if (source_rows == null) {
            source_rows = new Gee.HashMap<E.Source, Tasks.SourceRow> ();
        }

        debug ("Adding row '%s'", source.dup_display_name ());
        if (!source_rows.has_key (source)) {
            source_rows[source] = new Tasks.SourceRow (source);

            listbox.add (source_rows[source]);
            listbox.show_all ();

            var selected_list = Application.settings.get_string ("selected-list");
            if (selected_list == "" && Tasks.Application.task_store.get_default_source () == source) {
                listbox.select_row (source_rows[source]);

            } else if (selected_list == source.uid) {
                listbox.select_row (source_rows[source]);
            }
        }
    }

    private void update_source (E.Source source) {
        if (!Tasks.Application.task_store.is_source_enabled (source)) {
            remove_source (source);

        } else if (!source_rows.has_key (source)) {
            add_source (source);

        } else {
            source_rows[source].update_request ();
            listview.update_request ();
        }
    }

    private void remove_source (E.Source source) {
        listbox.unselect_row (source_rows[source]);
        source_rows[source].remove_request ();
        source_rows.unset (source);
    }

    private void components_added (Gee.Collection<ECal.Component> components, E.Source source, Gee.Collection<ECal.ClientView> views) {
        foreach( var view in views ) {
            if (taskviews.contains (view)) {
                listview.add_tasks (components, source);
                break;
            }
        }
    }

    private void components_modified (Gee.Collection<ECal.Component> components, E.Source source, Gee.Collection<ECal.ClientView> views) {
        foreach( var view in views ) {
            if (taskviews.contains (view)) {
                listview.modify_tasks (components, source);
                break;
            }
        }
    }

    private void components_removed (Gee.Collection<ECal.Component> components, E.Source source, Gee.Collection<ECal.ClientView> views) {
        foreach( var view in views ) {
            if (taskviews.contains (view)) {
                listview.remove_tasks (components);
                break;
            }
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
