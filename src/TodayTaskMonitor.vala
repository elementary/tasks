/*
* Copyright 2021 elementary, Inc. (https://elementary.io)
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
*/

public class Tasks.TodayTaskMonitor : GLib.Object {

    private Tasks.TaskModel model;
    private GLib.HashTable<E.Source, ECal.ClientView> task_list_view;
    private GLib.HashTable<ECal.ComponentId, Notification> task_notification;

    construct {
        task_list_view = new GLib.HashTable<E.Source, ECal.ClientView> (E.Source.hash, E.Source.equal);
        task_notification = new GLib.HashTable<ECal.ComponentId, GLib.Notification> (ECal.ComponentId.hash, ECal.ComponentId.equal);
    }

    public async void start () throws Error {
        model = new Tasks.TaskModel ();
        model.task_list_added.connect (add_task_list);
        model.task_list_modified.connect (modify_task_list);
        model.task_list_removed.connect (remove_task_list);

        yield model.start ();

        // we force refreshing the queries every 10 hours
        // this makes sure the query time window of
        // +/- 12 hours is moved to match the current time.
        Timeout.add_seconds (36000, refresh_task_list_queries);
    }

    public bool refresh_task_list_queries () {
        var task_lists = task_list_view.get_keys ();
        foreach (unowned var task_list in task_lists) {
            debug ("[%s] Refreshing task list query…", task_list.display_name);
            modify_task_list (task_list);
        }

        return GLib.Source.CONTINUE;
    }

    private void add_task_list (E.Source task_list) {
        debug ("[%s] Adding task list…", task_list.display_name);

        var now_datetime = new GLib.DateTime.now_local ();

        var range_start = now_datetime.add_hours (-12);
        var range_end = now_datetime.add_hours (12);

        var iso8601_date_format = "%Y%m%d";
        var iso8601_time_format = "%H%M%S";

        var task_list_query = """(AND (NOT is-completed?) (due-in-time-range? (make-time "%sT%sZ") (make-time "%sT%sZ"))))""".printf (
            range_start.format (iso8601_date_format),
            range_start.format (iso8601_time_format),
            range_end.format (iso8601_date_format),
            range_end.format (iso8601_time_format)
        );

        debug ("[%s] Creating task list view with query: %s", task_list.display_name, task_list_query);

        try {
            model.create_task_list_view (
                task_list,
                task_list_query,
                (tasks, task_list) => { add_tasks (tasks); },
                modify_tasks,
                remove_tasks
            );
            debug ("[%s] Task list view created.", task_list.display_name);

        } catch (Error e) {
            warning ("Error creating view for '%s': %s", task_list.display_name, e.message);
        }
    }

    private void modify_task_list (E.Source task_list) {
        remove_task_list (task_list);
        add_task_list (task_list);
    }

    private void remove_task_list (E.Source task_list) {
        debug ("[%s] Removing task list…", task_list.display_name);

        lock (task_list_view) {
            bool exists;

            var view = task_list_view.take (task_list, out exists);
            if (exists) {
                model.destroy_task_list_view (view);
                debug ("[%s] Task list view destroyed.", task_list.display_name);
            }
        }
    }

    private void add_tasks (Gee.Collection<ECal.Component> tasks) {
        foreach (var task in tasks) {
            unowned var ical_component = task.get_icalcomponent ();
            var due_icaltime = ical_component.get_due ();

            if (due_icaltime.is_null_time () || !due_icaltime.is_valid_time ()) {
                continue;
            }

            var notification = new GLib.Notification (ical_component.get_summary ());
            if (ical_component.get_description () != null) {
                notification.set_body (ical_component.get_description ());
            }

            lock (task_notification) {
                task_notification.insert (task.get_id ().copy (), notification);
            }

            var now_datetime = new GLib.DateTime.now ();
            var due_datetime = Util.icaltime_to_datetime (due_icaltime);

            var timespan = due_datetime.difference (now_datetime) / 1000000;
            if (timespan < 0) {
                timespan = 0;
            }
            uint timeout_in_seconds = (uint) timespan;

            debug ("[%s] Creating notification for task '%s' to be sent in %u seconds…",
                format_ecal_component_id (task.get_id ()),
                ical_component.get_summary (),
                timeout_in_seconds
            );

            GLib.Timeout.add_seconds (timeout_in_seconds, () => {
                send_notification (task.get_id ());
                return GLib.Source.REMOVE;
            });
        }
    }

    private void modify_tasks (Gee.Collection<ECal.Component> tasks) {
        var cids = new SList<ECal.ComponentId?> ();
        foreach (var task in tasks) {
            cids.append (task.get_id ());
        }
        remove_tasks (cids);
        add_tasks (tasks);
    }

    private void remove_tasks (SList<ECal.ComponentId?> cids) {
        lock (task_notification) {
            foreach (var cid in cids) {
                task_notification.remove (cid);
                debug ("[%s] Removed notification for task.", format_ecal_component_id (cid));
            }
        }
    }

    private void send_notification (ECal.ComponentId cid) {
        lock (task_notification) {
            bool exists;
            var notification = task_notification.take (cid, out exists);
            if (exists) {
                GLib.Application.get_default ().send_notification (
                    "%s-%u".printf (format_ecal_component_id (cid), GLib.Random.next_int ()),
                    notification
                );
                debug ("[%s] Sent notification for task.", format_ecal_component_id (cid));
            }
        }
    }

    private string format_ecal_component_id (ECal.ComponentId cid) {
        if (cid.get_rid () == null) {
            return cid.get_uid ();
        }

        return "%s-%s".printf (cid.get_uid (), cid.get_rid ());
    }
}
