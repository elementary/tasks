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

public class Tasks.TaskListModel : Object {

    public E.SourceRegistry registry { get; private set; }

    /* Notifies when events are added, updated, or removed */
    public signal void tasks_added (E.Source source, Gee.Collection<ECal.Component> tasks);
    public signal void tasks_updated (E.Source source, Gee.Collection<ECal.Component> tasks);
    public signal void tasks_removed (E.Source source, Gee.Collection<ECal.Component> tasks);

    public signal void connecting (E.Source source, Cancellable cancellable);
    public signal void connected (E.Source source);
    public signal void error_received (string error);

    HashTable<string, ECal.Client> source_client;
    HashTable<string, ECal.ClientView> source_view;
    HashTable<E.Source, Gee.TreeMultiMap<string, ECal.Component>> source_tasks;

    private static Tasks.TaskListModel? tasks_model = null;

    public static TaskListModel get_default () {
        if (tasks_model == null)
            tasks_model = new TaskListModel ();
        return tasks_model;
    }

    private TaskListModel () {
        source_client = new HashTable<string, ECal.Client> (str_hash, str_equal);
        source_tasks = new HashTable<E.Source, Gee.TreeMultiMap<string, ECal.Component>> (Util.source_hash_func, Util.source_equal_func);
        source_view = new HashTable<string, ECal.ClientView> (str_hash, str_equal);

        open.begin ();
    }

    public async void open () {
        try {
            registry = yield new E.SourceRegistry (null);
            //credentials_prompter = new E.CredentialsPrompter (registry);
            //credentials_prompter.set_auto_prompt (true);
            registry.source_removed.connect (remove_source);
            registry.source_changed.connect (on_source_changed);
            registry.source_added.connect (add_source);

            // Add sources
            registry.list_sources (E.SOURCE_EXTENSION_TASK_LIST).foreach ((source) => {
                E.SourceTaskList list = (E.SourceTaskList)source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);
                if (list.selected == true && source.enabled == true) {
                    add_source (source);
                }
            });

        } catch (GLib.Error error) {
            critical (error.message);
        }
    }

    public void load_all_sources () {
        lock (source_client) {
            foreach (var id in source_client.get_keys ()) {
                var source = registry.ref_source (id);
                E.SourceTaskList list = (E.SourceTaskList)source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);
                if (list.selected == true && source.enabled == true) {
                    load_source (source);
                }
            }
        }
    }

    public void add_source (E.Source source) {
        add_source_async.begin (source);
    }

    public void remove_source (E.Source source) {
        debug ("Removing source '%s'", source.dup_display_name ());
        // Already out of the model, so do nothing
        unowned string uid = source.get_uid ();
        if (!source_view.contains (uid)) {
            return;
        }

        var current_view = source_view.get (uid);
        try {
            current_view.stop ();
        } catch (Error e) {
            warning (e.message);
        }

        source_view.remove (uid);
        lock (source_client) {
            source_client.remove (uid);
        }

        var tasks = source_tasks.get (source).get_values ().read_only_view;
        tasks_removed (source, tasks);
        source_tasks.remove (source);
    }

    private void load_source (E.Source source) {
        // create empty source-event map
        var tasks = new Gee.TreeMultiMap<string, ECal.Component> (
            (GLib.CompareDataFunc<string>?) GLib.strcmp,
            (GLib.CompareDataFunc<ECal.Component>?) Util.calcomponent_compare_func);
        source_tasks.set (source, tasks);
        // query client view
        var iso_last = ECal.isodate_from_time_t ((time_t) new GLib.DateTime.now ().to_unix ());
        var iso_first = ECal.isodate_from_time_t ((time_t) new GLib.DateTime.now ().add_years (-1).to_unix ());
        var query = @"(occur-in-time-range? (make-time \"$iso_first\") (make-time \"$iso_last\"))";

        ECal.Client client;
        lock (source_client) {
            client = source_client.get (source.dup_uid ());
        }

        if (client == null)
            return;

        debug ("Getting client-view for source '%s'", source.dup_display_name ());
        client.get_view.begin (query, null, (obj, results) => {
            ECal.ClientView view;
            debug ("Received client-view for source '%s'", source.dup_display_name ());
            try {
                client.get_view.end (results, out view);
                view.objects_added.connect ((objects) => on_objects_added (source, client, objects));
                view.objects_removed.connect ((objects) => on_objects_removed (source, client, objects));
                view.objects_modified.connect ((objects) => on_objects_modified (source, client, objects));
                view.start ();
            } catch (Error e) {
                critical ("Error from source '%s': %s", source.dup_display_name (), e.message);
            }

            source_view.set (source.dup_uid (), view);
        });
    }

    private async void add_source_async (E.Source source) {
        debug ("Adding source '%s'", source.dup_display_name ());
        try {
            var cancellable = new GLib.Cancellable ();
            connecting (source, cancellable);
            var client = (ECal.Client) yield ECal.Client.connect (source, ECal.ClientSourceType.TASKS, 30, cancellable);
            source_client.insert (source.get_uid (), client);
        } catch (Error e) {
            error_received (e.message);
        }

        Idle.add (() => {
            connected (source);
            load_source (source);
            return false;
        });
    }

    private void debug_task (E.Source source, ECal.Component task) {
        unowned ICal.Component comp = task.get_icalcomponent ();
        debug (@"Task ['$(comp.get_summary())', $(source.dup_display_name()), $(comp.get_uid()))]");
    }

    private void on_source_changed (E.Source source) {

    }

    #if E_CAL_2_0
    private void on_objects_added (E.Source source, ECal.Client client, SList<ICal.Component> objects) {
#else
    private void on_objects_added (E.Source source, ECal.Client client, SList<weak ICal.Component> objects) {
#endif
        debug (@"Received $(objects.length()) added task(s) for source '%s'", source.dup_display_name ());
        var tasks = source_tasks.get (source);
        var added_tasks = new Gee.ArrayList<ECal.Component> ((Gee.EqualDataFunc<ECal.Component>?) Util.calcomponent_equal_func);
        objects.foreach ((comp) => {
            unowned string uid = comp.get_uid ();
            var unix_last = (time_t) new GLib.DateTime.now ().to_unix ();
            var unix_first = (time_t) new GLib.DateTime.now ().add_years (-1).to_unix ();

#if E_CAL_2_0
            //client.generate_instances_for_object_sync (comp, (time_t) data_range.first_dt.to_unix (), (time_t) data_range.last_dt.to_unix (), null, (comp, start, end) => {
            client.generate_instances_for_object_sync (comp, unix_first, unix_last, null, (comp, start, end) => {
                var task = new ECal.Component.from_icalcomponent (comp);
                debug_task (source, task);
                tasks.set (uid, task);
                added_tasks.add (task);
                return true;
            });
#else
            //client.generate_instances_for_object_sync (comp, (time_t) data_range.first_dt.to_unix (), (time_t) data_range.last_dt.to_unix (), (task, start, end) => {
            //client.generate_instances_for_object_sync (comp, unix_first, unix_last, (task, start, end) => {
#endif
             //   debug_task (source, task);
              //  tasks.set (uid, task);
               // added_tasks.add (task);
               // return true;
            //});
        });

        tasks_added (source, added_tasks.read_only_view);
    }

#if E_CAL_2_0
    private void on_objects_modified (E.Source source, ECal.Client client, SList<ICal.Component> objects) {
#else
    private void on_objects_modified (E.Source source, ECal.Client client, SList<weak ICal.Component> objects) {
#endif
        debug (@"Received $(objects.length()) modified task(s) for source '%s'", source.dup_display_name ());
        var updated_tasks = new Gee.ArrayList<ECal.Component> ((Gee.EqualDataFunc<ECal.Component>?) Util.calcomponent_equal_func);
        objects.foreach ((comp) => {
            unowned string uid = comp.get_uid ();
            var tasks = source_tasks.get (source).get (uid);
            updated_tasks.add_all (tasks);
            foreach (var task in tasks) {
                debug_task (source, task);
            }
        });

        tasks_updated (source, updated_tasks.read_only_view);
    }

#if E_CAL_2_0
    private void on_objects_removed (E.Source source, ECal.Client client, SList<ECal.ComponentId?> cids) {
#else
    private void on_objects_removed (E.Source source, ECal.Client client, SList<weak ECal.ComponentId?> cids) {
#endif
        debug (@"Received $(cids.length()) removed task(s) for source '%s'", source.dup_display_name ());
        var tasks = source_tasks.get (source);
        var removed_tasks = new Gee.ArrayList<ECal.Component> ((Gee.EqualDataFunc<ECal.Component>?) Util.calcomponent_equal_func);
        cids.foreach ((cid) => {
            if (cid == null)
                return;

            var comps = tasks.get (cid.get_uid ());
            foreach (ECal.Component task in comps) {
                removed_tasks.add (task);
                debug_task (source, task);
            }
        });

        tasks_removed (source, removed_tasks.read_only_view);
    }
}
