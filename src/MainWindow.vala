/*
 * Copyright 2019-2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Tasks.MainWindow : Gtk.ApplicationWindow {
    public const string ACTION_GROUP_PREFIX = "win";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    public const string ACTION_DELETE_SELECTED_LIST = "action-delete-selected-list";

    private const string SCHEDULED_LIST_UID = "scheduled";

    private const ActionEntry[] ACTION_ENTRIES = {
        { ACTION_DELETE_SELECTED_LIST, action_delete_selected_list }
    };

    private static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

    private Gtk.ListBox listbox;
    private Gee.HashMap<E.Source, Tasks.Widgets.SourceRow>? source_rows;
    private Gee.Collection<E.Source>? collection_sources;
    private Gtk.Stack task_list_grid_stack;
    private Gtk.Box add_tasklist_buttonbox;
    private Gtk.Popover add_tasklist_popover;

    public MainWindow (Gtk.Application application) {
        Object (
            application: application,
            icon_name: "io.elementary.tasks",
            title: _("Tasks")
        );
    }

    static construct {
        action_accelerators[ACTION_DELETE_SELECTED_LIST] = "<Control>BackSpace";
    }

    construct {
        add_action_entries (ACTION_ENTRIES, this);

        unowned var application_instance = (Gtk.Application) GLib.Application.get_default ();
        foreach (var action in action_accelerators.get_keys ()) {
            application_instance.set_accels_for_action (
                ACTION_PREFIX + action, action_accelerators[action].to_array ()
            );
        }

        listbox = new Gtk.ListBox ();
        listbox.set_sort_func (sort_function);

        var scheduled_row = new Tasks.Widgets.ScheduledRow ();
        listbox.append (scheduled_row);

        var sidebar_header = new Gtk.HeaderBar () {
            title_widget = new Gtk.Label (null),
            show_title_buttons = false
        };
        sidebar_header.add_css_class (Granite.STYLE_CLASS_DEFAULT_DECORATION);
        sidebar_header.add_css_class (Granite.STYLE_CLASS_FLAT);
        sidebar_header.pack_start (new Gtk.WindowControls (Gtk.PackType.START));

        var scrolledwindow = new Gtk.ScrolledWindow () {
            hexpand = true,
            vexpand = true,
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            child = listbox
        };

        add_tasklist_buttonbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6); // TODO: check spacing

        var online_accounts_button = new Widgets.PopoverButton ();
        online_accounts_button.append (new Gtk.Label (_("Online Accounts Settings…")));

        var add_tasklist_box = new Gtk.Box (VERTICAL, 3) {
            margin_top = 3,
            margin_bottom = 3
        };
        add_tasklist_box.append (add_tasklist_buttonbox);
        add_tasklist_box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        add_tasklist_box.append (online_accounts_button);

        add_tasklist_popover = new Gtk.Popover () {
            child = add_tasklist_box
        };

        var add_tasklist_button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        add_tasklist_button_box.append (new Gtk.Image.from_icon_name ("list-add-symbolic"));
        add_tasklist_button_box.append (new Gtk.Label (_("Add Task List…")));

        var add_tasklist_button = new Gtk.MenuButton () {
            popover = add_tasklist_popover,
            direction = Gtk.ArrowType.UP,
            child = add_tasklist_button_box
        };

        var actionbar = new Gtk.ActionBar ();
        actionbar.add_css_class (Granite.STYLE_CLASS_FLAT);
        actionbar.pack_start (add_tasklist_button);

        var sidebar = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        sidebar.add_css_class (Granite.STYLE_CLASS_SIDEBAR);
        sidebar.append (sidebar_header);
        sidebar.append (scrolledwindow);
        sidebar.append (actionbar);

        var main_header = new Gtk.HeaderBar () {
            title_widget = new Gtk.Label (null),
            show_title_buttons = false
        };
        main_header.add_css_class (Granite.STYLE_CLASS_DEFAULT_DECORATION);
        main_header.add_css_class (Granite.STYLE_CLASS_FLAT);
        main_header.pack_end (new Gtk.WindowControls (Gtk.PackType.END));

        task_list_grid_stack = new Gtk.Stack ();

        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        main_box.add_css_class (Granite.STYLE_CLASS_BACKGROUND);
        main_box.append (main_header);
        main_box.append (task_list_grid_stack);

        var paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL) {
            start_child = sidebar,
            end_child = main_box,
            resize_start_child = false,
            shrink_end_child = false,
            shrink_start_child = false
        };

        child = paned;

        // We need to hide the title area for the split headerbar
        titlebar = new Gtk.Grid () { visible = false };

        var settings = new GLib.Settings ("io.elementary.tasks");
        settings.bind ("window-width", this, "default-width", SettingsBindFlags.DEFAULT);
        settings.bind ("window-height", this, "default-height", SettingsBindFlags.DEFAULT);
        settings.bind ("window-maximized", this, "maximized", SettingsBindFlags.DEFAULT);

        close_request.connect (() => {
            ((Application)application).request_background.begin (() => destroy ());

            return Gdk.EVENT_STOP;
        });

        online_accounts_button.clicked.connect (() => {
            add_tasklist_popover.popdown ();

            try {
                AppInfo.launch_default_for_uri ("settings://accounts/online", null);
            } catch (Error e) {
                warning ("Failed to open account settings: %s", e.message);
            }
        });

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

            listbox.row_selected.connect (on_listbox_row_selected);

            add_collection_source (registry.ref_builtin_task_list ());

            var task_list_collections = registry.list_sources (E.SOURCE_EXTENSION_COLLECTION);
            task_list_collections.foreach ((collection_source) => {
                add_collection_source (collection_source);
            });

            var last_selected_list = Application.settings.get_string ("selected-list");

            if (last_selected_list == SCHEDULED_LIST_UID) {
                listbox.select_row (scheduled_row);
                listbox.row_selected (scheduled_row);

            } else {
                var default_task_list = registry.default_task_list;
                var task_lists = registry.list_sources (E.SOURCE_EXTENSION_TASK_LIST);

                task_lists.foreach ((source) => {
                    unowned var list = (E.SourceTaskList)source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);

                    if (list.selected == true && source.enabled == true && !source.has_extension (E.SOURCE_EXTENSION_COLLECTION)) {
                        add_source (source);

                        if (last_selected_list == "" && default_task_list == source) {
                            assert (source_rows[source] != null);
                            listbox.select_row (source_rows[source]);

                        } else if (last_selected_list == source.uid) {
                            assert (source_rows[source] != null);
                            listbox.select_row (source_rows[source]);
                        }
                    }
                });
            }
        });
    }

    private void on_listbox_row_selected (Gtk.ListBoxRow? row) {
        if (row != null) {
            Tasks.Widgets.TaskListGrid? task_list_grid = null;

            if (row is Tasks.Widgets.SourceRow) {
                var source = ((Tasks.Widgets.SourceRow) row).source;
                var source_uid = source.dup_uid ();

                /* Synchronizing the list whenever its selected discovers task changes done on remote (likely to happen when multiple devices are used) */
                Tasks.Application.model.refresh_task_list.begin (source, null, (obj, res) => {
                    try {
                        Tasks.Application.model.refresh_task_list.end (res);
                    } catch (Error e) {
                        warning ("Error syncing task list '%s': %s", source.dup_display_name (), e.message);
                    }
                });

                task_list_grid = (Tasks.Widgets.TaskListGrid) task_list_grid_stack.get_child_by_name (source_uid);
                if (task_list_grid == null) {
                    task_list_grid = new Tasks.Widgets.TaskListGrid (source);
                    task_list_grid_stack.add_named (task_list_grid, source_uid);
                }

                task_list_grid_stack.set_visible_child_name (source_uid);
                Tasks.Application.settings.set_string ("selected-list", source_uid);
                ((SimpleAction) lookup_action (ACTION_DELETE_SELECTED_LIST)).set_enabled (Tasks.Application.model.is_remove_task_list_supported (source));

            } else if (row is Tasks.Widgets.ScheduledRow) {
                var scheduled_task_list_grid = (Tasks.Widgets.ScheduledTaskListBox) task_list_grid_stack.get_child_by_name (SCHEDULED_LIST_UID);
                if (scheduled_task_list_grid == null) {
                    scheduled_task_list_grid = new Tasks.Widgets.ScheduledTaskListBox (Tasks.Application.model);
                    task_list_grid_stack.add_named (scheduled_task_list_grid, SCHEDULED_LIST_UID);
                }

                task_list_grid_stack.set_visible_child_name (SCHEDULED_LIST_UID);
                Tasks.Application.settings.set_string ("selected-list", SCHEDULED_LIST_UID);
                ((SimpleAction) lookup_action (ACTION_DELETE_SELECTED_LIST)).set_enabled (false);
            }

            if (task_list_grid != null) {
                task_list_grid.update_request ();
            }

        } else {
            ((SimpleAction) lookup_action (ACTION_DELETE_SELECTED_LIST)).set_enabled (false);
            var first_row = listbox.get_row_at_index (0);
            if (first_row != null) {
                listbox.select_row (first_row);
            }
        }
    }

    private void add_new_list (E.Source collection_source) {
        var error_dialog_primary_text = _("Creating a new task list failed");
        var error_dialog_secondary_text = _("The task list registry may be unavailable or unable to be written to.");

        try {
            var new_source = new E.Source (null, null);
            unowned var new_source_tasklist_extension = (E.SourceTaskList) new_source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);
            new_source.display_name = _("New list");
            new_source_tasklist_extension.color = "#0e9a83";

            Tasks.Application.model.add_task_list.begin (new_source, collection_source, (obj, res) => {
                try {
                    Application.model.add_task_list.end (res);
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
            error_dialog.present ();
            error_dialog.response.connect (() => {
                error_dialog.destroy ();
            });

            return GLib.Source.REMOVE;
        });
    }

    private void action_delete_selected_list () {
        unowned var list_row = ((Tasks.Widgets.SourceRow) listbox.get_selected_row ());
        var source = list_row.source;

        if (Tasks.Application.model.is_remove_task_list_supported (source)) {
            var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _("Delete “%s”?").printf (source.display_name),
                _("The list and all its tasks will be permanently deleted. If you've shared this list, other people will no longer have access."),
                "edit-delete",
                Gtk.ButtonsType.CANCEL
            ) {
                badge_icon = new ThemedIcon ("dialog-question"),
                transient_for = this
            };

            unowned var trash_button = message_dialog.add_button (_("Delete Anyway"), Gtk.ResponseType.YES);
            trash_button.add_css_class (Granite.STYLE_CLASS_DESTRUCTIVE_ACTION);

            message_dialog.present ();
            message_dialog.response.connect ((response_id) => {
                var response = (Gtk.ResponseType) response_id;
                if (response == Gtk.ResponseType.YES) {
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
                }

                message_dialog.destroy ();
            });
        } else {
            Gdk.Display.get_default ().beep ();
        }
    }

    private void header_update_func (Gtk.ListBoxRow lbrow, Gtk.ListBoxRow? lbbefore) {
        if (!(lbrow is Tasks.Widgets.SourceRow)) {
            return;
        }
        var row = (Tasks.Widgets.SourceRow) lbrow;
        if (lbbefore != null && lbbefore is Tasks.Widgets.SourceRow) {
            var before = (Tasks.Widgets.SourceRow) lbbefore;
            if (row.source.parent == before.source.parent) {
                row.set_header (null);
                return;
            }
        }

        var header_label = new Granite.HeaderLabel (Util.get_esource_collection_display_name (row.source)) {
            //  ellipsize = Pango.EllipsizeMode.MIDDLE,
            margin_start = 6
        };

        row.set_header (header_label);
    }

    [CCode (instance_pos = -1)]
    private int sort_function (Gtk.ListBoxRow lbrow, Gtk.ListBoxRow lbbefore) {
        if (!(lbrow is Tasks.Widgets.SourceRow)) {
            return -1;
        }
        var row = (Tasks.Widgets.SourceRow) lbrow;
        var before = (Tasks.Widgets.SourceRow) lbbefore;
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

        var source_button = new Widgets.PopoverButton () {
            sensitive = Application.model.is_add_task_list_supported (collection_source)
        };
        source_button.append (new Gtk.Label (Util.get_esource_collection_display_name (collection_source)));

        source_button.clicked.connect (() => {
            add_tasklist_popover.popdown ();

            add_new_list (collection_source);
        });

        add_tasklist_buttonbox.append (source_button);
    }

    private void add_source (E.Source source) {
        if (source_rows == null) {
            source_rows = new Gee.HashMap<E.Source, Tasks.Widgets.SourceRow> ();
        }

        debug ("Adding row '%s'", source.dup_display_name ());
        if (!source_rows.has_key (source)) {
            source_rows[source] = new Tasks.Widgets.SourceRow (source);

            listbox.append (source_rows[source]);
            Idle.add (() => {
                listbox.invalidate_sort ();
                listbox.invalidate_headers ();

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

            unowned var task_list_grid = (Tasks.Widgets.TaskListGrid) task_list_grid_stack.get_visible_child ();
            if (task_list_grid != null) {
                task_list_grid.update_request ();
            }

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
}
