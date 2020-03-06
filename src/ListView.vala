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

public class Tasks.ListView : Gtk.Grid {
    public E.Source? source { get; set; }

    private ECal.ClientView view;
    private EditableLabel editable_title;

    private Gtk.ListBox add_task_list;
    private Gtk.ListBox task_list;

    construct {
        editable_title = new EditableLabel ();
        editable_title.margin_start = 24;

        unowned Gtk.StyleContext title_context = editable_title.get_style_context ();
        title_context.add_class (Granite.STYLE_CLASS_H1_LABEL);
        title_context.add_class (Granite.STYLE_CLASS_ACCENT);

        var list_settings_popover = new Tasks.ListSettingsPopover ();

        var settings_button = new Gtk.MenuButton ();
        settings_button.margin_end = 24;
        settings_button.valign = Gtk.Align.CENTER;
        settings_button.tooltip_text = _("Edit Name and Appearance");
        settings_button.popover = list_settings_popover;
        settings_button.image = new Gtk.Image.from_icon_name ("view-more-symbolic", Gtk.IconSize.MENU);
        settings_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        settings_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var placeholder = new Gtk.Label (_("No Tasks"));
        placeholder.show ();

        unowned Gtk.StyleContext placeholder_context = placeholder.get_style_context ();
        placeholder_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        placeholder_context.add_class (Granite.STYLE_CLASS_H2_LABEL);

        add_task_list = new Gtk.ListBox ();
        add_task_list.selection_mode = Gtk.SelectionMode.NONE;
        add_task_list.margin_top = 24;
        add_task_list.get_style_context ().add_class (Gtk.STYLE_CLASS_BACKGROUND);

        task_list = new Gtk.ListBox ();
        task_list.selection_mode = Gtk.SelectionMode.NONE;
        task_list.set_filter_func (filter_function);
        task_list.set_placeholder (placeholder);
        task_list.set_sort_func (sort_function);
        task_list.get_style_context ().add_class (Gtk.STYLE_CLASS_BACKGROUND);

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.expand = true;
        scrolled_window.add (task_list);

        margin_bottom = 3;
        column_spacing = 12;
        attach (editable_title, 0, 0);
        attach (settings_button, 1, 0);
        attach (add_task_list, 0, 1, 2);
        attach (scrolled_window, 0, 2, 2);

        Application.settings.changed["show-completed"].connect (() => {
            task_list.invalidate_filter ();
        });

        settings_button.toggled.connect (() => {
            if (settings_button.active) {
                list_settings_popover.source = source;
            }
        });

        add_task_list.row_activated.connect ((row) => {
            ((Tasks.TaskRow) row).reveal_child_request (true);
        });

        task_list.row_activated.connect ((row) => {
            ((Tasks.TaskRow) row).reveal_child_request (true);
        });

        notify["source"].connect (() => {
            foreach (unowned Gtk.Widget child in add_task_list.get_children ()) {
                child.destroy ();
            }

            foreach (unowned Gtk.Widget child in task_list.get_children ()) {
                child.destroy ();
            }

            if (source != null) {
                update_request ();

                try {
                     var client = (ECal.Client) ECal.Client.connect_sync (source, ECal.ClientSourceType.TASKS, -1, null);

                     var add_task_row = new Tasks.TaskRow.for_source (source);
                     add_task_row.task_save.connect ((task) => {
                         add_task (client, task);
                     });
                     add_task_list.add (add_task_row);

                     /*
                      * We need to pass a valid S-expression to guarantee the below callback events are fired.
                      *
                      * See `e-cal-backend-sexp.c` of evolution-data-server for available S-expressions:
                      * https://gitlab.gnome.org/GNOME/evolution-data-server/-/blob/master/src/calendar/libedata-cal/e-cal-backend-sexp.c
                      */
                     client.get_view_sync ("(contains? 'any' '')", out view, null);

                     view.objects_added.connect ((objects) => on_objects_added (source, client, objects));
                     view.objects_removed.connect ((objects) => on_objects_removed (source, client, objects));
                     view.objects_modified.connect ((objects) => on_objects_modified (source, client, objects));

                     view.start ();

                 } catch (Error e) {
                     critical (e.message);
                 }
            } else {
                editable_title.text = "";
            }

            show_all ();
        });

        editable_title.changed.connect (() => {
            source.display_name = editable_title.text;
            source.write.begin (null);
        });
    }

    public void update_request () {
        editable_title.text = source.dup_display_name ();
        Tasks.Application.set_task_color (source, editable_title);
    }

    [CCode (instance_pos = -1)]
    private bool filter_function (Gtk.ListBoxRow row) {
        if (
            Application.settings.get_boolean ("show-completed") == false &&
            ((TaskRow) row).completed
        ) {
            return false;
        }

        return true;
    }

#if E_CAL_2_0
    private void on_objects_added (E.Source source, ECal.Client client, SList<ICal.Component> objects) {
#else
    private void on_objects_added (E.Source source, ECal.Client client, SList<weak ICal.Component> objects) {
#endif
        debug (@"Received $(objects.length()) added task(s) for source '%s'", source.dup_display_name ());
        var added_tasks = new Gee.ArrayList<ECal.Component> ((Gee.EqualDataFunc<ECal.Component>?) Util.calcomponent_equal_func);
        objects.foreach ((ical_comp) => {
            try {
                SList<ECal.Component> ecal_tasks;
                client.get_objects_for_uid_sync (ical_comp.get_uid (), out ecal_tasks, null);

                ecal_tasks.foreach ((task) => {
                    debug_task (source, task);

                    if (!added_tasks.contains (task)) {
                        added_tasks.add (task);
                    }
                });

            } catch (Error e) {
                warning (e.message);
            }
        });

        tasks_added (client, source, added_tasks.read_only_view);
    }

    private void tasks_added (ECal.Client client, E.Source source, Gee.Collection<ECal.Component> tasks) {
        tasks.foreach ((task) => {
            var task_row = new Tasks.TaskRow.for_component (task, source);
            task_row.task_save.connect ((task) => {
                update_task (client, task, ECal.ObjModType.ALL);
            });
            task_row.task_delete.connect ((task) => {
                remove_task (client, task, ECal.ObjModType.ALL);
            });
            task_list.add (task_row);
            return true;
        });
        task_list.show_all ();
    }

#if E_CAL_2_0
    private void on_objects_modified (E.Source source, ECal.Client client, SList<ICal.Component> objects) {
#else
    private void on_objects_modified (E.Source source, ECal.Client client, SList<weak ICal.Component> objects) {
#endif
        debug (@"Received $(objects.length()) modified task(s) for source '%s'", source.dup_display_name ());
        var updated_tasks = new Gee.ArrayList<ECal.Component> ((Gee.EqualDataFunc<ECal.Component>?) Util.calcomponent_equal_func);
        objects.foreach ((comp) => {
            try {
                SList<ECal.Component> ecal_tasks;
                client.get_objects_for_uid_sync (comp.get_uid (), out ecal_tasks, null);

                ecal_tasks.foreach ((task) => {
                    debug_task (source, task);
                    if (!updated_tasks.contains (task)) {
                        updated_tasks.add (task);
                    }
                });

            } catch (Error e) {
                warning (e.message);
            }
        });

        tasks_updated (client, source, updated_tasks.read_only_view);
    }


    private void tasks_updated (ECal.Client client, E.Source source, Gee.Collection<ECal.Component> tasks) {
        Tasks.TaskRow task_row = null;
        var row_index = 0;

        do {
            task_row = (Tasks.TaskRow) task_list.get_row_at_index (row_index);

            if (task_row != null) {
                foreach (ECal.Component task in tasks) {
                    if (Util.calcomponent_equal_func (task_row.task, task)) {
                        task_row.task = task;
                        break;
                    }
                }
            }
            row_index++;
        } while (task_row != null);
    }

#if E_CAL_2_0
    private void on_objects_removed (E.Source source, ECal.Client client, SList<ECal.ComponentId?> cids) {
#else
    private void on_objects_removed (E.Source source, ECal.Client client, SList<weak ECal.ComponentId?> cids) {
#endif
        debug (@"Received $(cids.length()) removed task(s) for source '%s'", source.dup_display_name ());

        unowned Tasks.TaskRow? task_row = null;
        var row_index = 0;
        do {
            task_row = (Tasks.TaskRow) task_list.get_row_at_index (row_index);

            if (task_row != null) {
                foreach (unowned ECal.ComponentId cid in cids) {
                    if (cid == null) {
                        continue;
                    } else if (cid.get_uid () == task_row.task.get_icalcomponent ().get_uid ()) {
                        task_list.remove (task_row);
                        break;
                    }
                }
            }
            row_index++;
        } while (task_row != null);
    }


    [CCode (instance_pos = -1)]
    private int sort_function (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        var row1_completed = ((Tasks.TaskRow) row1).completed;
        var row2_completed = ((Tasks.TaskRow) row2).completed;

        if (row1_completed && !row2_completed) {
            return 1;
        } else if (row2_completed && !row1_completed) {
            return -1;
        }

        return 0;
    }

    public void add_task (ECal.Client client, ECal.Component task) {
        add_task_async.begin (client, task);
    }

    private async void add_task_async (ECal.Client client, ECal.Component task) {
        unowned ICal.Component comp = task.get_icalcomponent ();
        debug (@"Adding task '$(comp.get_uid())'");

        if (client != null) {
            try {
                string? uid;
#if E_CAL_2_0
                yield client.create_object (comp, ECal.OperationFlags.NONE, null, out uid);
#else
                yield client.create_object (comp, null, out uid);
#endif
                if (uid != null) {
                    comp.set_uid (uid);
                }
            } catch (GLib.Error error) {
                critical (error.message);
            }
        } else {
            critical ("No list was found, task not added");
        }
    }

    public void update_task (ECal.Client client, ECal.Component task, ECal.ObjModType mod_type) {
        unowned ICal.Component comp = task.get_icalcomponent ();
        debug (@"Updating task '$(comp.get_uid())' [mod_type=$(mod_type)]");

#if E_CAL_2_0
        client.modify_object.begin (comp, mod_type, ECal.OperationFlags.NONE, null, (obj, results) => {
#else
        client.modify_object.begin (comp, mod_type, null, (obj, results) => {
#endif
            try {
                client.modify_object.end (results);
                SList<ECal.Component> ecal_tasks;
                client.get_objects_for_uid_sync (comp.get_uid (), out ecal_tasks, null);

#if E_CAL_2_0
                var ical_tasks = new SList<ICal.Component> ();
#else
                var ical_tasks = new SList<unowned ICal.Component> ();
#endif
                foreach (unowned ECal.Component ecal_task in ecal_tasks) {
                    ical_tasks.append (ecal_task.get_icalcomponent ());
                }
                on_objects_modified (source, client, ical_tasks);

            } catch (Error e) {
                warning (e.message);
            }
        });
    }

    public void remove_task (ECal.Client client, ECal.Component task, ECal.ObjModType mod_type) {
        unowned ICal.Component comp = task.get_icalcomponent ();
        string uid = comp.get_uid ();
        string? rid = task.has_recurrences () ? null : task.get_recurid_as_string ();
        debug (@"Removing task '$uid'");

#if E_CAL_2_0
        client.remove_object.begin (uid, rid, mod_type, ECal.OperationFlags.NONE, null, (obj, results) => {
#else
        client.remove_object.begin (uid, rid, mod_type, null, (obj, results) => {
#endif
            try {
                client.remove_object.end (results);
            } catch (Error e) {
                warning (e.message);
            }
        });
    }

    private void debug_task (E.Source source, ECal.Component task) {
        unowned ICal.Component comp = task.get_icalcomponent ();
        debug (@"Task ['$(comp.get_summary())', $(source.dup_display_name()), $(comp.get_uid()))]");
    }
}
