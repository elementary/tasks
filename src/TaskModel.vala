/*
* Copyright 2020 elementary, Inc. (https://elementary.io)
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

public class Tasks.TaskModel : Object {

    /*
     * 1: registry
     *  - n: source
     *      - 1: client
     *          - n: query -> view
     *              n: objects
     *
     * 1. Init registry
     * 2. Load all sources
     * 3. create one client per source
     * 4. provide method to view one source with a custom query
     * 5. make sure the view gets closed if a source is removed
     * 6. provide a method to view all sources with a custom query
     * 7. make sure the view gets updated if one or more sources are removed
     */

    public signal void task_list_added (E.Source task_list);
    public signal void task_list_changed (E.Source task_list);
    public signal void task_list_removed (E.Source task_list);

    private E.SourceRegistry registry;
    private HashTable<string, ECal.Client> source_client;
    private HashTable<string, Gee.Collection<ECal.ClientView>> source_views;

    public E.Source default_task_list {
        get {
            return registry.default_task_list;
        }
    }

    construct {
        open.begin ();

        source_client = new HashTable<string, ECal.Client> (str_hash, str_equal);
        source_views = new HashTable<string, Gee.Collection<ECal.ClientView>> (str_hash, str_equal);
    }

    private async void open () {
        try {
            registry = yield new E.SourceRegistry (null);

            registry.source_removed.connect ((source) => {
                remove_source (source);
                task_list_removed (source);
            });

            registry.source_changed.connect ((source) => {
                task_list_changed (source);
            });

            registry.source_added.connect ((source) => {
                add_source_async.begin (source, () => {
                    task_list_added (source);
                });
            });

            list_task_lists ().foreach ((source) => {
                E.SourceTaskList task_list = (E.SourceTaskList)source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);
                if (task_list.selected == true && source.enabled == true) {
                    add_source_async.begin (source);
                }
            });

        } catch (GLib.Error error) {
            critical (error.message);
        }
    }

    public List<E.Source> list_task_lists () {
        return registry.list_sources (E.SOURCE_EXTENSION_TASK_LIST);
    }

    private void remove_source (E.Source source) {
        debug ("Removing source '%s'", source.dup_display_name ());
        /* Already out of the model, so do nothing */
        unowned string uid = source.get_uid ();

        if (!source_views.contains (uid)) {
            return;
        }

        foreach (var source_view in source_views.get (uid)) {
            try {
                source_view.stop ();
            } catch (Error e) {
                warning (e.message);
            }
        }

        source_views.remove (uid);
        lock (source_client) {
            source_client.remove (uid);
        }

        //var tasks = source_events.get (source).get_values ().read_only_view;
        //events_removed (source, events);
        //source_events.remove (source);
    }

/*    private void load_source (E.Source source) {
        var iso_first = ECal.isodate_from_time_t ((time_t)data_range.first_dt.to_unix ());
        var iso_last = ECal.isodate_from_time_t ((time_t)data_range.last_dt.add_days (1).to_unix ());
        var query = @"(occur-in-time-range? (make-time \"$iso_first\") (make-time \"$iso_last\"))";

        ECal.Client client;
        lock (source_client) {
            client = source_client.get (source.dup_uid ());
        }

        if (client == null) {
            return;
        }

        debug ("Getting client-view for source '%s'", source.dup_display_name ());
        client.get_view.begin (query, null, (obj, results) => {
            var view = on_client_view_received (results, source, client);
            view.objects_added.connect ((objects) => on_objects_added (source, client, objects));
            view.objects_removed.connect ((objects) => on_objects_removed (source, client, objects));
            view.objects_modified.connect ((objects) => on_objects_modified (source, client, objects));
            try {
                view.start ();
            } catch (Error e) {
                //critical (e.message);
            }

            source_view.set (source.dup_uid (), view);
        });
    }
*/
    private async void add_source_async (E.Source source) {
        debug ("Adding source '%s'", source.dup_display_name ());
        try {
            var client = (ECal.Client) ECal.Client.connect_sync (source, ECal.ClientSourceType.TASKS, -1, null);
            source_client.insert (source.dup_uid (), client);
        } catch (Error e) {
            critical (e.message);
        }
    }

    private void debug_task (E.Source source, ECal.Component task) {
        unowned ICal.Component comp = task.get_icalcomponent ();
        debug (@"Task ['$(comp.get_summary())', $(source.dup_display_name()), $(comp.get_uid()))]");
    }
/*
    private ECal.ClientView on_client_view_received (AsyncResult results, E.Source source, ECal.Client client) {
        ECal.ClientView view;
        try {
            debug ("Received client-view for source '%s'", source.dup_display_name ());
            bool status = client.get_view.end (results, out view);
            assert (status == true);
        } catch (Error e) {
            critical ("Error loading client-view from source '%s': %s", source.dup_display_name (), e.message);
        }

        return view;
    }
*/

/*
#if E_CAL_2_0
    private void on_objects_added (E.Source source, ECal.Client client, SList<ICal.Component> objects) {
#else
    private void on_objects_added (E.Source source, ECal.Client client, SList<weak ICal.Component> objects) {
#endif
        debug (@"Received $(objects.length()) added event(s) for source '%s'", source.dup_display_name ());
        var events = source_events.get (source);
        var added_events = new Gee.ArrayList<ECal.Component> ((Gee.EqualDataFunc<ECal.Component>?) Util.calcomponent_equal_func); // vala-lint=line-length

        objects.foreach ((comp) => {
            unowned string uid = comp.get_uid ();
#if E_CAL_2_0
            client.generate_instances_for_object_sync (comp, (time_t) data_range.first_dt.to_unix (), (time_t) data_range.last_dt.to_unix (), null, (comp, start, end) => { // vala-lint=line-length
                var event = new ECal.Component.from_icalcomponent (comp);
#else
            client.generate_instances_for_object_sync (comp, (time_t) data_range.first_dt.to_unix (), (time_t) data_range.last_dt.to_unix (), (event, start, end) => { // vala-lint=line-length
#endif
                debug_event (source, event);
                events.set (uid, event);
                added_events.add (event);
                return true;
            });
        });

        events_added (source, added_events.read_only_view);
    }
*/

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

        //tasks_added (client, source, added_tasks.read_only_view);
    }

/*
#if E_CAL_2_0
    private void on_objects_modified (E.Source source, ECal.Client client, SList<ICal.Component> objects) {
#else
    private void on_objects_modified (E.Source source, ECal.Client client, SList<weak ICal.Component> objects) {
#endif
        debug (@"Received $(objects.length()) modified event(s) for source '%s'", source.dup_display_name ());
        var updated_events = new Gee.ArrayList<ECal.Component> ((Gee.EqualDataFunc<ECal.Component>?) Util.calcomponent_equal_func); // vala-lint=line-length

        objects.foreach ((comp) => {
            unowned string uid = comp.get_uid ();
            var events = source_events.get (source).get (uid);
            updated_events.add_all (events);
            foreach (var event in events) {
                debug_event (source, event);
            }
        });

        events_updated (source, updated_events.read_only_view);
    }
*/

/*
#if E_CAL_2_0
        private void on_objects_removed (E.Source source, ECal.Client client, SList<ECal.ComponentId?> cids) {
#else
        private void on_objects_removed (E.Source source, ECal.Client client, SList<weak ECal.ComponentId?> cids) {
#endif
        debug (@"Received $(cids.length()) removed event(s) for source '%s'", source.dup_display_name ());
        var events = source_events.get (source);
        var removed_events = new Gee.ArrayList<ECal.Component> ((Gee.EqualDataFunc<ECal.Component>?) Util.calcomponent_equal_func); // vala-lint=line-length

        cids.foreach ((cid) => {
            if (cid == null) {
                return;
            }

            var comps = events.get (cid.get_uid ());
            foreach (ECal.Component event in comps) {
                removed_events.add (event);
                debug_event (source, event);
            }
        });

        events_removed (source, removed_events.read_only_view);
    }
*/
}
