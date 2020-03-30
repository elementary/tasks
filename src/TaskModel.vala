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


errordomain Tasks.TaskModelError {
    CLIENT_NOT_AVAILABLE
}


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
    public signal void registry_ready (E.SourceRegistry registry);

    public signal void task_list_added (E.Source task_list);
    public signal void task_list_changed (E.Source task_list);
    public signal void task_list_removed (E.Source task_list);

    public delegate void TasksAddedFunc (Gee.Collection<ECal.Component> tasks);
    public delegate void TasksModifiedFunc (Gee.Collection<ECal.Component> tasks);
    public delegate void TasksRemovedFunc (SList<ECal.ComponentId?> cids);

    private Gee.Future<E.SourceRegistry> registry;
    private HashTable<string, ECal.Client> source_client;
    private HashTable<ECal.Client, Gee.Collection<ECal.ClientView>> client_views;

    /** BLOCKS until the E.SourceRegistry is available.
     * Returns the E.SourceRegistry or rethrows the exception
     * thrown while trying to establish the connection.
     */
    public E.SourceRegistry get_registry () throws Error {
        registry.wait ();
        return registry.value;
    }

    construct {
        var promise =  new Gee.Promise<E.SourceRegistry> ();
        registry = promise.future;
        init_registry.begin (promise);

        source_client = new HashTable<string, ECal.Client> (str_hash, str_equal);
        client_views = new HashTable<ECal.Client, Gee.Collection<ECal.ClientView>> (direct_hash, direct_equal);
    }

    private async void init_registry (Gee.Promise<E.SourceRegistry> promise) {
        try {
            var registry = yield new E.SourceRegistry (null);

            registry.source_added.connect ((source) => {
                add_source (source);
                task_list_added (source);
            });

            registry.source_changed.connect ((source) => {
                task_list_changed (source);
            });

            registry.source_removed.connect ((source) => {
                remove_source (source);
                task_list_removed (source);
            });

            registry.list_sources (E.SOURCE_EXTENSION_TASK_LIST).foreach ((source) => {
                E.SourceTaskList task_list = (E.SourceTaskList)source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);
                if (task_list.selected == true && source.enabled == true) {
                    add_source (source);
                }
            });

            promise.set_value (registry);
            registry_ready (registry);

        } catch (Error e) {
            critical (e.message);
            promise.set_exception (e);
        }
    }

    private void add_source (E.Source source) {
        debug ("Adding source '%s'", source.dup_display_name ());
        try {
            var client = (ECal.Client) ECal.Client.connect_sync (source, ECal.ClientSourceType.TASKS, -1, null);
            source_client.insert (source.dup_uid (), client);
        } catch (Error e) {
            critical (e.message);
        }
    }

    private void remove_source (E.Source source) {
        debug ("Removing source '%s'", source.dup_display_name ());
        /* Already out of the model, so do nothing */
        unowned string uid = source.get_uid ();

        ECal.Client client;
        lock (source_client) {
            client = source_client.get (uid);
        }

        if (client == null) {
            return;
        }

        if (!client_views.contains (client)) {
            return;
        }

        foreach (var view in client_views.get (client)) {
            try {
                view.stop ();
            } catch (Error e) {
                warning (e.message);
            }
        }

        client_views.remove (client);
        lock (source_client) {
            source_client.remove (uid);
        }

        //var tasks = source_events.get (source).get_values ().read_only_view;
        //events_removed (source, events);
        //source_events.remove (source);
    }

    private void debug_task (E.Source source, ECal.Component task) {
        unowned ICal.Component comp = task.get_icalcomponent ();
        debug (@"Task ['$(comp.get_summary())', $(source.dup_display_name()), $(comp.get_uid()))]");
    }

    public void destroy_view (ECal.ClientView view) {
        try {
            view.stop ();
        } catch (Error e) {
            warning (e.message);
        }

        lock (client_views) {
            unowned Gee.Collection<ECal.ClientView> task_list_views = client_views.get (view.client);

            if (task_list_views != null) {
                task_list_views.remove (view);
            }
        }
    }

    public ECal.ClientView create_view_for_list (E.Source task_list, string query, TasksAddedFunc on_tasks_added, TasksModifiedFunc on_tasks_modified, TasksRemovedFunc on_tasks_removed) throws Error { // vala-lint=line-length
        unowned string source_uid = task_list.get_uid ();

        ECal.Client client;
        lock (source_client) {
            client = source_client.get (source_uid);
        }

        if (client == null) {
            throw new Tasks.TaskModelError.CLIENT_NOT_AVAILABLE ("No client available for task-list '%s'".printf(task_list.dup_display_name ()));
        }
        debug ("Getting view for task-list '%s'", task_list.dup_display_name ());

        ECal.ClientView view;
        client.get_view_sync (query, out view, null);

        view.objects_added.connect ((objects) => on_objects_added (task_list, client, objects, on_tasks_added));
        view.objects_removed.connect ((objects) => on_objects_removed (task_list, client, objects, on_tasks_removed));
        view.objects_modified.connect ((objects) => on_objects_modified (task_list, client, objects, on_tasks_modified));
        view.start ();

        Gee.Collection<ECal.ClientView> task_list_views;
        lock (client_views) {
            task_list_views = client_views.get (client);
        }

        if (task_list_views == null) {
            task_list_views = new Gee.ArrayList<ECal.ClientView> ((Gee.EqualDataFunc<ECal.ClientView>?) direct_equal);
        }
        task_list_views.add (view);

        lock (client_views) {
            client_views.set (client, task_list_views);
        }

        return view;
    }

#if E_CAL_2_0
    private void on_objects_added (E.Source source, ECal.Client client, SList<ICal.Component> objects, TasksAddedFunc on_tasks_added) {
#else
    private void on_objects_added (E.Source source, ECal.Client client, SList<weak ICal.Component> objects, TasksAddedFunc on_tasks_added) {
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

        on_tasks_added (added_tasks.read_only_view);
    }
/*
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
    */

#if E_CAL_2_0
    private void on_objects_modified (E.Source source, ECal.Client client, SList<ICal.Component> objects, TasksModifiedFunc on_tasks_modified) {
#else
    private void on_objects_modified (E.Source source, ECal.Client client, SList<weak ICal.Component> objects, TasksModifiedFunc on_tasks_modified) {
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

        on_tasks_modified (updated_tasks.read_only_view);
    }


 /*   private void tasks_updated (ECal.Client client, E.Source source, Gee.Collection<ECal.Component> tasks) {
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
    }*/

#if E_CAL_2_0
    private void on_objects_removed (E.Source source, ECal.Client client, SList<ECal.ComponentId?> cids, TasksRemovedFunc on_tasks_removed) {
#else
    private void on_objects_removed (E.Source source, ECal.Client client, SList<weak ECal.ComponentId?> cids, TasksRemovedFunc on_tasks_removed) {
#endif
        debug (@"Received $(cids.length()) removed task(s) for source '%s'", source.dup_display_name ());

        on_tasks_removed (cids);
/*
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
        */
    }
}
