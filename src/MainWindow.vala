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

public class Tasks.MainWindow : Hdy.ApplicationWindow {
    public const string ACTION_PREFIX = "win.";
    public const string ACTION_ADD_NEW_LIST = "action-add-new-list";
    public const string ACTION_DELETE_SELECTED_LIST = "action-delete-selected-list";

    private const ActionEntry[] ACTION_ENTRIES = {
        { ACTION_ADD_NEW_LIST, action_add_new_list },
        { ACTION_DELETE_SELECTED_LIST, action_delete_selected_list }
    };

    private static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

    private uint configure_id;
    private Gtk.ListBox listbox;
    private Gee.HashMap<E.Source, Tasks.SourceRow>? source_rows;
    private Gee.Collection<E.Source>? source_collections;
    private Tasks.ListView listview;
    private Gtk.Popover add_tasklist_popover;
    private Gtk.ButtonBox add_tasklist_buttonbox;
    private E.SourceRegistryWatcher source_collection_watcher;

    public MainWindow (Gtk.Application application) {
        Object (
            application: application,
            icon_name: "io.elementary.tasks",
            title: _("Tasks")
        );
    }

    static construct {
        Hdy.init ();

        action_accelerators[ACTION_ADD_NEW_LIST] = "<Control>N";
        action_accelerators[ACTION_DELETE_SELECTED_LIST] = "<Control>BackSpace";
        action_accelerators[ACTION_DELETE_SELECTED_LIST] = "Delete";
    }

    construct {
        add_action_entries (ACTION_ENTRIES, this);

        var application_instance = (Gtk.Application) GLib.Application.get_default ();
        foreach (var action in action_accelerators.get_keys ()) {
            application_instance.set_accels_for_action (
                ACTION_PREFIX + action, action_accelerators[action].to_array ()
            );
        }

        var header_provider = new Gtk.CssProvider ();
        header_provider.load_from_resource ("io/elementary/tasks/HeaderBar.css");

        var sidebar_header = new Hdy.HeaderBar ();
        sidebar_header.decoration_layout = "close:";
        sidebar_header.has_subtitle = false;
        sidebar_header.show_close_button = true;

        unowned Gtk.StyleContext sidebar_header_context = sidebar_header.get_style_context ();
        sidebar_header_context.add_class ("sidebar-header");
        sidebar_header_context.add_class ("default-decoration");
        sidebar_header_context.add_class (Gtk.STYLE_CLASS_FLAT);
        sidebar_header_context.add_provider (header_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var listview_header = new Hdy.HeaderBar ();
        listview_header.has_subtitle = false;
        listview_header.decoration_layout = ":maximize";
        listview_header.show_close_button = true;

        unowned Gtk.StyleContext listview_header_context = listview_header.get_style_context ();
        listview_header_context.add_class ("default-decoration");
        listview_header_context.add_class (Gtk.STYLE_CLASS_FLAT);

        listbox = new Gtk.ListBox ();
        listbox.set_sort_func (sort_function);

        var scheduled_row = new Tasks.ScheduledRow ();
        listbox.add (scheduled_row);

        var scrolledwindow = new Gtk.ScrolledWindow (null, null);
        scrolledwindow.expand = true;
        scrolledwindow.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolledwindow.add (listbox);

        /*var add_tasklist_button = new Gtk.Button () {
            action_name = ACTION_PREFIX + ACTION_ADD_NEW_LIST,
            always_show_image = true,
            image = new Gtk.Image.from_icon_name ("list-add-symbolic", Gtk.IconSize.SMALL_TOOLBAR),
            label = _("Add Task List…"),
            tooltip_markup = Granite.markup_accel_tooltip (
                application_instance.get_accels_for_action (ACTION_PREFIX + ACTION_ADD_NEW_LIST)
            )
        };*/

        add_tasklist_popover = new Gtk.Popover (null);
        add_tasklist_buttonbox = new Gtk.ButtonBox (Gtk.Orientation.VERTICAL);
        add_tasklist_popover.add (add_tasklist_buttonbox);

        var add_tasklist_button = new Gtk.MenuButton () {
            label = ("Add Task List…"),
            image = new Gtk.Image.from_icon_name ("list-add-symbolic", Gtk.IconSize.SMALL_TOOLBAR),
            always_show_image = true,
            popover = add_tasklist_popover
        };

        var actionbar = new Gtk.ActionBar ();
        actionbar.add (add_tasklist_button);

        unowned Gtk.StyleContext actionbar_style_context = actionbar.get_style_context ();
        actionbar_style_context.add_class (Gtk.STYLE_CLASS_FLAT);

        var sidebar = new Gtk.Grid ();
        sidebar.attach (sidebar_header, 0, 0);
        sidebar.attach (scrolledwindow, 0, 1);
        sidebar.attach (actionbar, 0, 2);

        unowned Gtk.StyleContext sidebar_style_context = sidebar.get_style_context ();
        sidebar_style_context.add_class (Gtk.STYLE_CLASS_SIDEBAR);

        listview = new Tasks.ListView ();

        var listview_grid = new Gtk.Grid ();
        listview_grid.attach (listview_header, 0, 0);
        listview_grid.attach (listview, 0, 1);

        var paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        paned.pack1 (sidebar, false, false);
        paned.pack2 (listview_grid, true, false);

        add (paned);

        Tasks.Application.settings.bind ("pane-position", paned, "position", GLib.SettingsBindFlags.DEFAULT);

        Tasks.Application.model.task_list_added.connect (add_source);
        Tasks.Application.model.task_list_modified.connect (update_source);
        Tasks.Application.model.task_list_removed.connect (remove_source);

        Tasks.Application.model.get_registry.begin ((obj, res) => {
            E.SourceRegistry registry;
            try {
                registry = Tasks.Application.model.get_registry.end (res);
            } catch (Error e) {
                critical (e.message);
                return;
            }

            source_collection_watcher = new E.SourceRegistryWatcher (registry, E.SOURCE_EXTENSION_COLLECTION);
            source_collection_watcher.appeared.connect (add_source_collection);
            source_collection_watcher.disappeared.connect (remove_source_collection);
            source_collection_watcher.reclaim ();

            listbox.set_header_func (header_update_func);

            listbox.row_selected.connect ((row) => {
                if (row != null) {
                    if (row is Tasks.SourceRow) {
                        var source = ((Tasks.SourceRow) row).source;
                        listview.source = source;
                        Tasks.Application.settings.set_string ("selected-list", source.uid);

                        listview.add_view (source, "(contains? 'any' '')");

                        ((SimpleAction) lookup_action (ACTION_DELETE_SELECTED_LIST)).set_enabled (source.removable);

                    } else if (row is Tasks.ScheduledRow) {
                        listview.source = null;
                        Tasks.Application.settings.set_string ("selected-list", "scheduled");

                        var sources = registry.list_sources (E.SOURCE_EXTENSION_TASK_LIST);
                        var query = "AND (NOT is-completed?) (OR (has-start?) (has-alarms?))";

                        sources.foreach ((source) => {
                            E.SourceTaskList list = (E.SourceTaskList)source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);

                            if (list.selected == true && source.enabled == true) {
                                listview.add_view (source, query);
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

            var last_selected_list = Application.settings.get_string ("selected-list");
            var default_task_list = registry.default_task_list;
            var task_lists = registry.list_sources (E.SOURCE_EXTENSION_TASK_LIST);

            task_lists.foreach ((source) => {
                E.SourceTaskList list = (E.SourceTaskList)source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);

                if (list.selected == true && source.enabled == true) {
                    add_source (source);

                    if (last_selected_list == "" && default_task_list == source) {
                        listbox.select_row (source_rows[source]);

                    } else if (last_selected_list == source.uid) {
                        listbox.select_row (source_rows[source]);
                    }
                }
            });

            if (last_selected_list == "scheduled") {
                listbox.select_row (scheduled_row);
            }
        });
    }

    private void action_add_new_list () {
        add_new_list (null);
    }

    private void add_new_list (E.Source? source) {
        var selected_source = source == null ? listview.source : source;

        if (selected_source == null) {
            add_tasklist_popover.popup ();
            return;
        }

        Tasks.Application.model.get_registry.begin ((obj, res) => {
            try {
                var registry = Tasks.Application.model.get_registry.end (res);
                var collection_source = registry.find_extension (selected_source, E.SOURCE_EXTENSION_COLLECTION);
                var collection_source_extension = (E.SourceCollection) collection_source.get_extension (E.SOURCE_EXTENSION_COLLECTION);

                var new_source = new E.Source (null, null);
                var new_source_tasklist_extension = (E.SourceTaskList) new_source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);
                new_source.display_name = _("New list");
                new_source_tasklist_extension.color = "#0e9a83";

                switch (collection_source_extension.backend_name) {
                    case "webdav":
                        var collection_source_webdav_session = new E.WebDAVSession (collection_source);
                        var credentials_provider = new E.SourceCredentialsProvider (registry);

                        E.NamedParameters credentials;
                        credentials_provider.lookup_sync (collection_source, null, out credentials);
                        collection_source_webdav_session.credentials = credentials;

                        E.webdav_discover_sources.begin (
                            collection_source,
                            collection_source_extension.calendar_url,
                            E.WebDAVDiscoverSupports.TASKS,
                            credentials,
                            null,
                            (obj, res) => {
                                string webdav_certificate_pem;
                                TlsCertificateFlags? webdav_certificate_errors;
                                SList<E.WebDAVDiscoveredSource?> webdav_discovered_sources;
                                SList<string> webdav_calendar_user_addresses;

                                try {
                                    /**
                                     * TEMPORARY WORKAROUND: `E.webdav_discover_sources_finish`
                                     * Use `E.webdav_discover_sources.end` once the following commit of libedataserver is released:
                                     * https://gitlab.gnome.org/GNOME/evolution-data-server/-/commit/4f4ea2f45d5e2bffcf446b9fdc1bb65e94982d03
                                     */
                                    E.webdav_discover_sources_finish (
                                        collection_source,
                                        res,
                                        out webdav_certificate_pem,
                                        out webdav_certificate_errors,
                                        out webdav_discovered_sources,
                                        out webdav_calendar_user_addresses
                                    );
    
                                    Soup.URI? new_source_uri = null;
                                    if (webdav_discovered_sources.length () > 0) {
                                        var webdav_discovered_source = webdav_discovered_sources.nth_data (0);
                                        new_source_uri = new Soup.URI (webdav_discovered_source.href.dup ());
                                    }
                                    /**
                                     * TEMPORARY WORKAROUND: `E.webdav_discover_do_free_discovered_sources`
                                     * Remove this line, once the following commit of libedataserver is released:
                                     * https://gitlab.gnome.org/GNOME/evolution-data-server/-/commit/9d1505cd3518ff32bd03050fd898abf89d31d389
                                     */
                                    E.webdav_discover_do_free_discovered_sources ((owned) webdav_discovered_sources);
    
                                    if (new_source_uri == null) {
                                        throw new Error (1,404, "Error resolving WebDAV endpoint from backend");
                                    }
    
                                    var uri_dir_path = new_source_uri.get_path ();
                                    if (uri_dir_path.has_suffix ("/")) {
                                        uri_dir_path = uri_dir_path.substring (0, uri_dir_path.length - 1);
                                    }
                                    uri_dir_path = uri_dir_path.substring (0, uri_dir_path.last_index_of ("/"));
                                    new_source_uri.set_path (uri_dir_path + "/" + GLib.Uuid.string_random ().up ());
    
                                    collection_source_webdav_session.mkcalendar_sync (
                                        new_source_uri.to_string (false),
                                        new_source.display_name,
                                        null,
                                        new_source_tasklist_extension.color,
                                        E.WebDAVResourceSupports.TASKS,
                                        null
                                    );
                                    registry.refresh_backend_sync (collection_source.uid, null);

                                } catch (Error e) {
                                    critical (e.message);
                                    dialog_add_task_list_error (e);
                                }
                            });
                        break;

                    case "google":
                        throw new Error (1,202, "Task list management for a Google backend is not supported yet.");

                    default:
                        new_source.parent = "local-stub";
                        new_source_tasklist_extension.backend_name = "local";

                        registry.commit_source_sync (new_source, null);
                        break;
                }

            } catch (Error e) {
                critical (e.message);
                dialog_add_task_list_error (e);
            }
        });
    }

    private void dialog_add_task_list_error (Error e) {
        string error_message = e.message;

        GLib.Idle.add (() => {
            var error_dialog = new Granite.MessageDialog (
                _("Creating a new task list failed"),
                _("The task list registry may be unavailable or unable to be written to."),
                new ThemedIcon ("dialog-error"),
                Gtk.ButtonsType.CLOSE
            ) {
                transient_for = this
            };
            error_dialog.show_error_details (error_message);
            error_dialog.run ();
            error_dialog.destroy ();

            return GLib.Source.REMOVE;
        });
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

        E.SourceRegistry registry;
        try {
            registry = Tasks.Application.model.get_registry_sync ();
        } catch (Error e) {
            warning (e.message);
            return;
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
        if (before.source.parent == null) {
            return -1;
        } else if (row.source.parent == before.source.parent) {
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
        }
    }

    private void update_source (E.Source source) {
        E.SourceTaskList list = (E.SourceTaskList)source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);

        if (list.selected != true || source.enabled != true) {
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

    private void add_source_collection (E.Source source_collection) {
        if (source_collections == null) {
            source_collections = new Gee.HashSet<E.Source> (Util.esource_hash_func, Util.esource_equal_func);
        }
        E.SourceTaskList source_collection_tasklist_extension = (E.SourceTaskList)source_collection.get_extension (E.SOURCE_EXTENSION_TASK_LIST);

        if (source_collections.contains (source_collection) || !source_collection.enabled || !source_collection_tasklist_extension.selected) {
            return;
        }
        source_collections.add (source_collection);
        update_add_tasklist_buttonbox ();
    }

    private void remove_source_collection (E.Source source_collection) {
        if (source_collections != null && source_collections.contains (source_collection)) {
            source_collections.remove (source_collection);
        }
        update_add_tasklist_buttonbox ();
    }

    private void update_add_tasklist_buttonbox () {
        foreach (var child in add_tasklist_buttonbox.get_children ()) {
            add_tasklist_buttonbox.remove (child);
        }
        foreach (var source_collection in source_collections) {
            var source_button = new Gtk.ModelButton () {
                text = source_collection.display_name
            };

            source_button.button_release_event.connect (() => {
                add_new_list (source_collection);
                return Gdk.EVENT_PROPAGATE;
            });

            add_tasklist_buttonbox.add (source_button);
        }
        add_tasklist_buttonbox.show_all ();
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
