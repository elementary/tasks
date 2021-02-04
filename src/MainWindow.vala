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
    public const string ACTION_DELETE_SELECTED_LIST = "action-delete-selected-list";

    private const ActionEntry[] ACTION_ENTRIES = {
        { ACTION_DELETE_SELECTED_LIST, action_delete_selected_list }
    };

    private static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

    private uint configure_id;
    private Gtk.ListBox listbox;
    private Gee.HashMap<E.Source, Tasks.SourceRow>? source_rows;
    private Gee.Collection<E.Source>? collection_sources;
    private Tasks.ListView listview;
    private Gtk.ButtonBox add_tasklist_buttonbox;

    public MainWindow (Gtk.Application application) {
        Object (
            application: application,
            icon_name: "io.elementary.tasks",
            title: _("Tasks")
        );
    }

    static construct {
        Hdy.init ();

        action_accelerators[ACTION_DELETE_SELECTED_LIST] = "<Control>BackSpace";
        action_accelerators[ACTION_DELETE_SELECTED_LIST] = "Delete";

        Gtk.IconTheme.get_default ().add_resource_path ("/io/elementary/tasks");
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

        var sidebar_header = new Hdy.HeaderBar () {
            decoration_layout = "close:",
            has_subtitle = false,
            show_close_button = true
        };

        unowned Gtk.StyleContext sidebar_header_context = sidebar_header.get_style_context ();
        sidebar_header_context.add_class ("sidebar-header");
        sidebar_header_context.add_class ("default-decoration");
        sidebar_header_context.add_class (Gtk.STYLE_CLASS_FLAT);
        sidebar_header_context.add_provider (header_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var listview_header = new Hdy.HeaderBar () {
            has_subtitle = false,
            decoration_layout = ":maximize",
            show_close_button = true
        };

        unowned Gtk.StyleContext listview_header_context = listview_header.get_style_context ();
        listview_header_context.add_class ("default-decoration");
        listview_header_context.add_class (Gtk.STYLE_CLASS_FLAT);

        listbox = new Gtk.ListBox ();
        listbox.set_sort_func (sort_function);

        var scheduled_row = new Tasks.ScheduledRow ();
        listbox.add (scheduled_row);

        var scrolledwindow = new Gtk.ScrolledWindow (null, null) {
            expand = true,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };
        scrolledwindow.add (listbox);

        add_tasklist_buttonbox = new Gtk.ButtonBox (Gtk.Orientation.VERTICAL);

        var add_tasklist_popover = new Gtk.Popover (null);
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
            listbox.set_header_func (header_update_func);

            listbox.row_selected.connect ((row) => {
                if (row != null) {
                    if (row is Tasks.SourceRow) {
                        var source = ((Tasks.SourceRow) row).source;
                        listview.source = source;
                        Tasks.Application.settings.set_string ("selected-list", source.uid);

                        listview.add_view (source, "(contains? 'any' '')");

                        ((SimpleAction) lookup_action (ACTION_DELETE_SELECTED_LIST)).set_enabled (Tasks.Application.model.is_remove_task_list_supported (source));

                    } else if (row is Tasks.ScheduledRow) {
                        listview.source = null;
                        Tasks.Application.settings.set_string ("selected-list", "scheduled");

                        var sources = registry.list_sources (E.SOURCE_EXTENSION_TASK_LIST);
                        var query = "AND (NOT is-completed?) (has-start?)";

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

            add_collection_source (registry.ref_builtin_task_list ());

            var task_list_collections = registry.list_sources (E.SOURCE_EXTENSION_COLLECTION);
            task_list_collections.foreach ((collection_source) => {
                add_collection_source (collection_source);
            });

            if (last_selected_list == "scheduled") {
                listbox.select_row (scheduled_row);
            }
        });
    }

    private void add_new_list (E.Source collection_source) {
        var error_dialog_primary_text = _("Creating a new task list failed");
        var error_dialog_secondary_text = _("The task list registry may be unavailable or unable to be written to.");

        try {
            var new_source = new E.Source (null, null);
            var new_source_tasklist_extension = (E.SourceTaskList) new_source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);
            new_source.display_name = _("New list");
            new_source_tasklist_extension.color = "#0e9a83";

            Tasks.Application.model.add_task_list.begin (new_source, collection_source, (obj, res) => {
                try {
                    Tasks.Application.model.add_task_list.end (res);
                } catch (Error e) {
                    critical (e.message);
                    show_error_dialog (error_dialog_primary_text, error_dialog_secondary_text, e);
                }
            });

        } catch (Error e) {
            critical (e.message);
            show_error_dialog (error_dialog_primary_text, error_dialog_secondary_text, e);
        }
    }

    private void show_error_dialog (string primary_text, string secondary_text, Error e) {
        string error_message = e.message;

        GLib.Idle.add (() => {
            var error_dialog = new Granite.MessageDialog (
                primary_text,
                secondary_text,
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

        if (Tasks.Application.model.is_remove_task_list_supported (source)) {
            Tasks.Application.model.remove_task_list.begin (source, (obj, res) => {
                try {
                    Tasks.Application.model.remove_task_list.end (res);
                } catch (Error e) {
                    critical (e.message);
                    show_error_dialog (
                        _("Deleting the task list failed"),
                        _("The task list registry may be unavailable or unable to be written to."),
                        e
                    );
                }
            });

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

        var header_label = new Granite.HeaderLabel (Util.get_esource_collection_display_name (row.source)) {
            ellipsize = Pango.EllipsizeMode.MIDDLE,
            margin_start = 6
        };

        row.set_header (header_label);
    }

    [CCode (instance_pos = -1)]
    private int sort_function (Gtk.ListBoxRow lbrow, Gtk.ListBoxRow lbbefore) {
        if (!(lbrow is Tasks.SourceRow)) {
            return -1;
        }
        var row = (Tasks.SourceRow) lbrow;
        var before = (Tasks.SourceRow) lbbefore;
        if (row.source.parent == null || before.source.parent == null) {
            return -1;
        } else if (row.source.parent == before.source.parent) {
            return row.source.display_name.collate (before.source.display_name);
        } else {
            return row.source.parent.collate (before.source.parent);
        }
    }

    private void add_collection_source (E.Source collection_source) {
        if (collection_sources == null) {
            collection_sources = new Gee.HashSet<E.Source> (Util.esource_hash_func, Util.esource_equal_func);
        }
        E.SourceTaskList collection_source_tasklist_extension = (E.SourceTaskList)collection_source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);

        if (collection_sources.contains (collection_source) || !collection_source.enabled || !collection_source_tasklist_extension.selected) {
            return;
        }
        collection_sources.add (collection_source);

        var source_button = new Gtk.ModelButton () {
            text = Util.get_esource_collection_display_name (collection_source),
            sensitive = Application.model.is_add_task_list_supported (collection_source)
        };

        source_button.clicked.connect (() => {
            add_new_list (collection_source);
        });

        add_tasklist_buttonbox.add (source_button);
        add_tasklist_buttonbox.show_all ();
    }

    private void add_source (E.Source source) {
        if (source_rows == null) {
            source_rows = new Gee.HashMap<E.Source, Tasks.SourceRow> ();
        }

        debug ("Adding row '%s'", source.dup_display_name ());
        if (!source_rows.has_key (source)) {
            source_rows[source] = new Tasks.SourceRow (source);

            listbox.add (source_rows[source]);
            Idle.add (() => {
                listbox.invalidate_sort ();
                listbox.invalidate_headers ();
                listbox.show_all ();

                return Source.REMOVE;
            });
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

            Idle.add (() => {
                listbox.invalidate_sort ();
                listbox.invalidate_headers ();

                return Source.REMOVE;
            });
        }
    }

    private void remove_source (E.Source source) {
        listbox.unselect_row (source_rows[source]);
        source_rows[source].remove_request ();
        source_rows.unset (source);

        Idle.add (() => {
            listbox.invalidate_sort ();
            listbox.invalidate_headers ();

            return Source.REMOVE;
        });
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
