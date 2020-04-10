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
        row_spacing = 24;
        attach (editable_title, 0, 0);
        attach (settings_button, 1, 0);
        attach (scrolled_window, 0, 1, 2);

        Application.settings.changed["show-completed"].connect (() => {
            task_list.invalidate_filter ();
        });

        settings_button.toggled.connect (() => {
            if (settings_button.active) {
                list_settings_popover.source = source;
            }
        });

        task_list.row_activated.connect ((row) => {
            ((Tasks.TaskRow) row).reveal_child_request (true);
        });

        notify["source"].connect (() => {
            foreach (unowned Gtk.Widget child in task_list.get_children ()) {
                child.destroy ();
            }

            if (source != null) {
                update_request ();

                try {
                     var client = (ECal.Client) ECal.Client.connect_sync (source, ECal.ClientSourceType.TASKS, -1, null);

                     var task_row = new Tasks.TaskRow.for_source (source);
                     task_row.task_changed.connect ((task) => {
                         add_task (client, task);
                     });
                     task_list.add (task_row);

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

        task_list.@foreach ((row) => {
            if (row is Tasks.TaskRow) {
                (row as Tasks.TaskRow).update_request ();
            }
        });
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
            if (ical_comp.get_uid () == null) {
                return;
            }

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
            task_row.task_completed.connect ((task) => {
                complete_task (client, task);
            });
            task_row.task_changed.connect ((task) => {
                update_task (client, task, ECal.ObjModType.THIS_AND_FUTURE);
            });
            task_row.task_removed.connect ((task) => {
                remove_task (client, task);
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
            if (comp.get_uid () == null) {
                return;
            }

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
        add_icalcomponent (client, task.get_icalcomponent ());
    }

    private void add_icalcomponent (ECal.Client client, ICal.Component comp) {
        debug (@"Adding instance for task '$(comp.get_uid())'");

        if (client != null) {
            try {
                string? uid;
#if E_CAL_2_0
                client.create_object_sync (comp, ECal.OperationFlags.NONE, null, out uid);
#else
                client.create_object_sync (comp, out uid, null);
#endif
                if (uid != null) {
                    comp.set_uid (uid);
                }
            } catch (GLib.Error error) {
                critical (error.message);
            }
        } else {
            critical ("No list was found, instance for task not added");
        }
    }

    public void complete_task (ECal.Client client, ECal.Component task) {
        unowned ICal.Component comp = task.get_icalcomponent ();
        var was_completed = comp.get_status () == ICal.PropertyStatus.COMPLETED;

        if (was_completed || !task.has_recurrences () || task.is_instance ()) {
            debug (@"Completing $(task.is_instance() ? "instance" : "task") '$(comp.get_uid())'");

            comp.set_status (comp.get_status () != ICal.PropertyStatus.COMPLETED ? ICal.PropertyStatus.COMPLETED : ICal.PropertyStatus.NONE);

            update_icalcomponent (client, comp, ECal.ObjModType.THIS_AND_PRIOR);

        } else {
            var duration = ICal.Duration.null_duration ();
            duration.weeks = 520; // roughly 10 years

            var today = ICal.Time.today ();
            var start = comp.get_dtstart ();
            if (today.compare (start) > 0) {
                start = today;
            }
            var end = start.add (duration);

            comp.set_status (ICal.PropertyStatus.COMPLETED);
            update_icalcomponent (client, comp, ECal.ObjModType.THIS_AND_PRIOR);

            ECal.RecurInstanceFn recur_instance_callback = (instance, instance_start_timet, instance_end_timet) => {
                unowned ICal.Component instance_comp = instance.get_icalcomponent ();

                if (!instance_comp.get_due ().is_null_time ()) {
                    instance_comp.set_due (instance_comp.get_dtstart ());
                }
                instance_comp.set_status (ICal.PropertyStatus.NONE);

                if (instance.has_alarms ()) {
                    instance.get_alarm_uids ().@foreach ((alarm_uid) => {
                        ECal.ComponentAlarmTrigger trigger;
#if E_CAL_2_0
                        trigger = ECal.ComponentAlarmTrigger.relative (ECal.ComponentAlarmTriggerKind.RELATIVE_START, ICal.Duration.null_duration ());
#else
                        trigger = ECal.ComponentAlarmTrigger () {
                            type = ECal.ComponentAlarmTriggerKind.RELATIVE_START,
                            rel_duration = ICal.Duration.null_duration ()
                        };
#endif
                        instance.get_alarm (alarm_uid).set_trigger (trigger);
                    });
                }

                update_icalcomponent (client, instance_comp, ECal.ObjModType.THIS_AND_FUTURE);
                return false; // only generate one instance
            };

            client.generate_instances_for_object_sync (comp, start.as_timet (), end.as_timet (), recur_instance_callback);
        }
    }

    public void update_task (ECal.Client client, ECal.Component task, ECal.ObjModType mod_type) {
        unowned ICal.Component comp = task.get_icalcomponent ();
        debug (@"Updating task '$(comp.get_uid())' [mod_type=$(mod_type)]");
        update_icalcomponent (client, comp, mod_type);
    }

    private void update_icalcomponent (ECal.Client client, ICal.Component comp, ECal.ObjModType mod_type) {
        try {
#if E_CAL_2_0
            client.modify_object_sync (comp, mod_type, ECal.OperationFlags.NONE, null);
#else
            client.modify_object_sync (comp, mod_type, null);
#endif
        } catch (Error e) {
            warning (e.message);
            return;
        }

        if (comp.get_uid () == null) {
            return;
        }

        try {
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
    }

    public void remove_task (ECal.Client client, ECal.Component task) {
        unowned ICal.Component comp = task.get_icalcomponent ();
        string uid = comp.get_uid ();
        string? rid = task.has_recurrences () ? null : task.get_recurid_as_string ();
        debug (@"Removing task '$uid'");

#if E_CAL_2_0
        client.remove_object.begin (uid, rid, ECal.ObjModType.ALL, ECal.OperationFlags.NONE, null, (obj, results) => {
#else
        client.remove_object.begin (uid, rid, ECal.ObjModType.ALL, null, (obj, results) => {
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
