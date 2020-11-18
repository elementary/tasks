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
    CLIENT_NOT_AVAILABLE,
    BACKEND_ERROR
}


public class Tasks.TaskModel : Object {

    public signal void task_list_added (E.Source task_list);
    public signal void task_list_modified (E.Source task_list);
    public signal void task_list_removed (E.Source task_list);

    public delegate void TasksAddedFunc (Gee.Collection<ECal.Component> tasks, E.Source task_list);
    public delegate void TasksModifiedFunc (Gee.Collection<ECal.Component> tasks);
    public delegate void TasksRemovedFunc (SList<ECal.ComponentId?> cids);

    private Gee.Future<E.SourceRegistry> registry;
    private HashTable<string, ECal.Client> task_list_client;
    private HashTable<ECal.Client, Gee.Collection<ECal.ClientView>> task_list_client_views;

    public async E.SourceRegistry get_registry () throws Error {
        return yield registry.wait_async ();
    }

    public E.SourceRegistry get_registry_sync () throws Error {
        if (!registry.ready) {
            debug ("Blocking until registry is loaded…");
            registry.wait ();
        }
        return registry.value;
    }

    private ECal.Client get_client (E.Source task_list) throws Error {
        ECal.Client client;
        lock (task_list_client) {
            client = task_list_client.get (task_list.dup_uid ());
        }

        if (client == null) {
            throw new Tasks.TaskModelError.CLIENT_NOT_AVAILABLE ("No client available for task list '%s'".printf (task_list.dup_display_name ()));  // vala-lint=line-length
        }

        return client;
    }

    private void create_task_list_client (E.Source task_list) {
        try {
            var client = (ECal.Client) ECal.Client.connect_sync (task_list, ECal.ClientSourceType.TASKS, -1, null);
            lock (task_list_client) {
                task_list_client.insert (task_list.dup_uid (), client);
            }

        } catch (Error e) {
            critical (e.message);
        }
    }

    private void destroy_task_list_client (E.Source task_list, ECal.Client client) {
        var views = get_views (client);
        foreach (var view in views) {
            try {
                view.stop ();
            } catch (Error e) {
                warning (e.message);
            }
        }

        lock (task_list_client_views) {
            task_list_client_views.remove (client);
        }

        lock (task_list_client) {
            task_list_client.remove (task_list.dup_uid ());
        }
    }

    private Gee.Collection<ECal.ClientView> get_views (ECal.Client client) {
        Gee.Collection<ECal.ClientView> views;
        lock (task_list_client_views) {
            views = task_list_client_views.get (client);
        }
        if (views == null) {
            views = new Gee.ArrayList<ECal.ClientView> ((Gee.EqualDataFunc<ECal.ClientView>?) direct_equal);
        }
        return views.read_only_view;
    }

    construct {
        var promise = new Gee.Promise<E.SourceRegistry> ();
        registry = promise.future;
        init_registry.begin (promise);

        task_list_client = new HashTable<string, ECal.Client> (str_hash, str_equal);
        task_list_client_views = new HashTable<ECal.Client, Gee.Collection<ECal.ClientView>> (direct_hash, direct_equal);  // vala-lint=line-length
    }

    private async void init_registry (Gee.Promise<E.SourceRegistry> promise) {
        try {
            var registry = yield new E.SourceRegistry (null);

            registry.source_added.connect ((task_list) => {
                debug ("Adding task list '%s'", task_list.dup_display_name ());
                create_task_list_client (task_list);
                task_list_added (task_list);
            });

            registry.source_changed.connect ((task_list) => {
                task_list_modified (task_list);
            });

            registry.source_removed.connect ((task_list) => {
                debug ("Removing task list '%s'", task_list.dup_display_name ());

                ECal.Client client;
                try {
                    client = get_client (task_list);
                } catch (Error e) {
                    /* Already out of the model, so do nothing */
                    warning (e.message);
                    return;
                }

                destroy_task_list_client (task_list, client);
                task_list_removed (task_list);
            });

            registry.list_sources (E.SOURCE_EXTENSION_TASK_LIST).foreach ((task_list) => {
                E.SourceTaskList task_list_extension = (E.SourceTaskList)task_list.get_extension (E.SOURCE_EXTENSION_TASK_LIST);  // vala-lint=line-length
                if (task_list_extension.selected == true && task_list.enabled == true) {
                    registry.source_added (task_list);
                }
            });

            promise.set_value (registry);

        } catch (Error e) {
            critical (e.message);
            promise.set_exception (e);
        }
    }

    public async void add_task_list_async (E.Source task_list, E.Source collection_or_sibling) throws Error {
        var registry = get_registry_sync ();
        var collection_source = registry.find_extension (collection_or_sibling, E.SOURCE_EXTENSION_COLLECTION);
        var collection_source_extension = (E.SourceCollection) collection_source.get_extension (E.SOURCE_EXTENSION_COLLECTION);
        var task_list_extension = (E.SourceTaskList) task_list.get_extension (E.SOURCE_EXTENSION_TASK_LIST);

        switch (collection_source_extension.backend_name) {
            case "webdav":
                var webdav_request_promise = new Gee.Promise<bool> ();
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
                        GLib.TlsCertificateFlags? webdav_certificate_errors;
                        GLib.SList<E.WebDAVDiscoveredSource?> webdav_discovered_sources;
                        GLib.SList<string> webdav_calendar_user_addresses;

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

                            Soup.URI? task_list_uri = null;
                            if (webdav_discovered_sources.length () > 0) {
                                var webdav_discovered_source = webdav_discovered_sources.nth_data (0);
                                task_list_uri = new Soup.URI (webdav_discovered_source.href.dup ());
                            }
                            /**
                             * TEMPORARY WORKAROUND: `E.webdav_discover_do_free_discovered_sources`
                             * Remove this line, once the following commit of libedataserver is released:
                             * https://gitlab.gnome.org/GNOME/evolution-data-server/-/commit/9d1505cd3518ff32bd03050fd898abf89d31d389
                             */
                            E.webdav_discover_do_free_discovered_sources ((owned) webdav_discovered_sources);

                            if (task_list_uri == null) {
                                throw new Tasks.TaskModelError.BACKEND_ERROR ("Unable to resolve the WebDAV endpoint from backend.");
                            }

                            var uri_dir_path = task_list_uri.get_path ();
                            if (uri_dir_path.has_suffix ("/")) {
                                uri_dir_path = uri_dir_path.substring (0, uri_dir_path.length - 1);
                            }
                            uri_dir_path = uri_dir_path.substring (0, uri_dir_path.last_index_of ("/"));
                            task_list_uri.set_path (uri_dir_path + "/" + GLib.Uuid.string_random ().up ());

                            collection_source_webdav_session.mkcalendar_sync (
                                task_list_uri.to_string (false),
                                task_list.display_name,
                                null,
                                task_list_extension.color,
                                E.WebDAVResourceSupports.TASKS,
                                null
                            );
                            registry.refresh_backend_sync (collection_source.uid, null);
                            webdav_request_promise.set_value (true);

                        } catch (Error e) {
                            webdav_request_promise.set_exception (e);
                        }
                    }
                );

                var webdav_timeout = new GLib.DateTime.now_local ().add_seconds (10);
                bool webdav_success;

                if (!webdav_request_promise.future.wait_until (webdav_timeout.to_unix (), out webdav_success) || !webdav_success) {
                    throw new Tasks.TaskModelError.BACKEND_ERROR ("The WebDAV backend took too long to respond.");
                }
                break;

            case "google":
                throw new Tasks.TaskModelError.BACKEND_ERROR ("Task list management for Google is not supported yet.");

            default:
                task_list.parent = "local-stub";
                task_list_extension.backend_name = "local";

                registry.commit_source_sync (task_list, null);
                break;
        }
    }

    public async void update_task_list_display_name (E.Source task_list, string display_name) throws Error {
        var registry = get_registry_sync ();
        var collection_source = registry.find_extension (task_list, E.SOURCE_EXTENSION_COLLECTION);

        if (collection_source != null && task_list.has_extension (E.SOURCE_EXTENSION_WEBDAV_BACKEND)) {
            debug ("WebDAV Rename '%s'", task_list.get_uid ());

            var collection_source_webdav_session = new E.WebDAVSession (collection_source);
            var source_webdav_extension = (E.SourceWebdav) task_list.get_extension (E.SOURCE_EXTENSION_WEBDAV_BACKEND);

            var credentials_provider = new E.SourceCredentialsProvider (registry);
            E.NamedParameters credentials;
            credentials_provider.lookup_sync (collection_source, null, out credentials);
            collection_source_webdav_session.credentials = credentials;

            var changes = new GLib.SList<E.WebDAVPropertyChange> ();
            changes.append (new E.WebDAVPropertyChange.set (
                E.WEBDAV_NS_DAV,
                "displayname",
                display_name
            ));

            E.webdav_session_update_properties_sync (
                collection_source_webdav_session,
                source_webdav_extension.soup_uri.to_string (false),
                changes,
                null
            );

            registry.refresh_backend_sync (collection_source.uid, null);

        } else if (task_list.parent == "local-stub") {
            debug ("Local Rename '%s'", task_list.get_uid ());

            task_list.display_name = display_name;
            registry.commit_source_sync (task_list, null);

        } else {
            throw new Tasks.TaskModelError.BACKEND_ERROR ("Renaming tasks list is not supported yet for this type of backend.");
        }
    }

    private void add_task_list (E.Source task_list) {
        debug ("Adding task list '%s'", task_list.dup_display_name ());
        create_task_list_client (task_list);
    }

    public void add_task (E.Source list, ECal.Component task) {
        add_task_async.begin (list, task);
    }

    private async void add_task_async (E.Source list, ECal.Component task) {
        ECal.Client client;
        try {
            client = get_client (list);
        } catch (Error e) {
            critical (e.message);
            return;
        }

        unowned ICal.Component comp = task.get_icalcomponent ();
        debug (@"Adding task '$(comp.get_uid())'");

        try {
            string? uid;
            yield client.create_object (comp, ECal.OperationFlags.NONE, null, out uid);
            if (uid != null) {
                comp.set_uid (uid);
            }
        } catch (GLib.Error error) {
            critical (error.message);
        }
    }

    public void complete_task (E.Source list, ECal.Component task) {
        ECal.Client client;
        try {
            client = get_client (list);
        } catch (Error e) {
            critical (e.message);
            return;
        }

        unowned ICal.Component comp = task.get_icalcomponent ();
        var was_completed = comp.get_status () == ICal.PropertyStatus.COMPLETED;

        if (was_completed) {
            debug (@"Reopen $(task.is_instance() ? "instance" : "task") '$(comp.get_uid())'");

            comp.set_status (ICal.PropertyStatus.NONE);
            task.set_percent_complete (0);

            task.set_completed (new ICal.Time.null_time ());

            update_icalcomponent (client, comp, ECal.ObjModType.ONLY_THIS);

        } else {
            debug (@"Completing $(task.is_instance() ? "instance" : "task") '$(comp.get_uid())'");

            comp.set_status (ICal.PropertyStatus.COMPLETED);
            task.set_percent_complete (100);
            task.set_completed (new ICal.Time.today ());

            update_icalcomponent (client, comp, ECal.ObjModType.THIS_AND_PRIOR);
        }

        if (task.has_recurrences () && !was_completed) {
            var duration = new ICal.Duration.null_duration ();
            duration.set_weeks (520); // roughly 10 years
            var today = new ICal.Time.today ();

            var start = comp.get_dtstart ();
            if (today.compare (start) > 0) {
                start = today;
            }
            var end = start.add (duration);

            ECal.RecurInstanceCb recur_instance_callback = (instance_comp, instance_start_timet, instance_end_timet, cancellable) => {

                var instance = new ECal.Component ();
                instance.set_icalcomponent (instance_comp);

                if (!instance_comp.get_due ().is_null_time ()) {
                    instance_comp.set_due (instance_comp.get_dtstart ());
                }

                instance_comp.set_status (ICal.PropertyStatus.NONE);
                instance.set_percent_complete (0);

                instance.set_completed (new ICal.Time.null_time ());

                if (instance.has_alarms ()) {
                    instance.get_alarm_uids ().@foreach ((alarm_uid) => {
                        ECal.ComponentAlarmTrigger trigger;
                        trigger = new ECal.ComponentAlarmTrigger.relative (ECal.ComponentAlarmTriggerKind.RELATIVE_START, new ICal.Duration.null_duration ());
                        instance.get_alarm (alarm_uid).set_trigger (trigger);
                    });
                }

                update_icalcomponent (client, instance_comp, ECal.ObjModType.THIS_AND_FUTURE);
                return false; // only generate one instance
            };

            client.generate_instances_for_object_sync (comp, start.as_timet (), end.as_timet (), null, recur_instance_callback);
        }
    }

    public void update_task (E.Source list, ECal.Component task, ECal.ObjModType mod_type) {
        ECal.Client client;
        try {
            client = get_client (list);
        } catch (Error e) {
            critical (e.message);
            return;
        }

        unowned ICal.Component comp = task.get_icalcomponent ();
        debug (@"Updating task '$(comp.get_uid())' [mod_type=$(mod_type)]");
        update_icalcomponent (client, comp, mod_type);
    }

    private void update_icalcomponent (ECal.Client client, ICal.Component comp, ECal.ObjModType mod_type) {
        client.modify_object.begin (comp, mod_type, ECal.OperationFlags.NONE, null, (obj, res) => {
            try {
                client.modify_object.end (res);
            } catch (Error e) {
                warning (e.message);
            }
        });
    }

    public void remove_task (E.Source list, ECal.Component task, ECal.ObjModType mod_type) {
        ECal.Client client;
        try {
            client = get_client (list);
        } catch (Error e) {
            critical (e.message);
            return;
        }

        unowned ICal.Component comp = task.get_icalcomponent ();
        string uid = comp.get_uid ();
        string? rid = task.has_recurrences () ? null : task.get_recurid_as_string ();
        debug (@"Removing task '$uid'");

        client.remove_object.begin (uid, rid, mod_type, ECal.OperationFlags.NONE, null, (obj, results) => {
            try {
                client.remove_object.end (results);
            } catch (Error e) {
                warning (e.message);
            }
        });
    }

    private void debug_task (E.Source task_list, ECal.Component task) {
        unowned ICal.Component comp = task.get_icalcomponent ();
        var task_summary = comp.get_summary ();
        var task_uid = comp.get_uid ();
        var task_list_display_name = task_list.dup_display_name ();

        if (task_summary == null)
            task_summary = "";

        if (task_uid == null)
            task_uid = "";

        if (task_list_display_name == null)
            task_list_display_name = "";

        debug (@"Task ['$(task_summary)', $(task_list_display_name), $(task_uid)))]");
    }

    public ECal.ClientView create_task_list_view (E.Source task_list, string query, TasksAddedFunc on_tasks_added, TasksModifiedFunc on_tasks_modified, TasksRemovedFunc on_tasks_removed) throws Error { // vala-lint=line-length
        ECal.Client client = get_client (task_list);
        debug ("Getting view for task list '%s'", task_list.dup_display_name ());

        ECal.ClientView view;
        client.get_view_sync (query, out view, null);

        view.objects_added.connect ((objects) => on_objects_added (task_list, client, objects, on_tasks_added));
        view.objects_removed.connect ((objects) => on_objects_removed (task_list, client, objects, on_tasks_removed));
        view.objects_modified.connect ((objects) => on_objects_modified (task_list, client, objects, on_tasks_modified));  // vala-lint=line-length
        view.start ();

        lock (task_list_client_views) {
            var views = task_list_client_views.get (client);

            if (views == null) {
                views = new Gee.ArrayList<ECal.ClientView> ((Gee.EqualDataFunc<ECal.ClientView>?) direct_equal);
            }
            views.add (view);

            task_list_client_views.set (client, views);
        }

        return view;
    }

    public void destroy_task_list_view (ECal.ClientView view) {
        try {
            view.stop ();
        } catch (Error e) {
            warning (e.message);
        }

        lock (task_list_client_views) {
            unowned Gee.Collection<ECal.ClientView> views = task_list_client_views.get (view.client);

            if (views != null) {
                views.remove (view);
            }
        }
    }

    private void on_objects_added (E.Source task_list, ECal.Client client, SList<ICal.Component> objects, TasksAddedFunc on_tasks_added) {  // vala-lint=line-length
        debug (@"Received $(objects.length()) added task(s) for task list '%s'", task_list.dup_display_name ());
        var added_tasks = new Gee.ArrayList<ECal.Component> ((Gee.EqualDataFunc<ECal.Component>?) Util.calcomponent_equal_func);  // vala-lint=line-length
        objects.foreach ((ical_comp) => {
            try {
                SList<ECal.Component> ecal_tasks;
                client.get_objects_for_uid_sync (ical_comp.get_uid (), out ecal_tasks, null);

                ecal_tasks.foreach ((task) => {
                    debug_task (task_list, task);

                    if (!added_tasks.contains (task)) {
                        added_tasks.add (task);
                    }
                });

            } catch (Error e) {
                warning (e.message);
            }
        });

        on_tasks_added (added_tasks.read_only_view, task_list);
    }

    private void on_objects_modified (E.Source task_list, ECal.Client client, SList<ICal.Component> objects, TasksModifiedFunc on_tasks_modified) {  // vala-lint=line-length
        debug (@"Received $(objects.length()) modified task(s) for task list '%s'", task_list.dup_display_name ());
        var updated_tasks = new Gee.ArrayList<ECal.Component> ((Gee.EqualDataFunc<ECal.Component>?) Util.calcomponent_equal_func);  // vala-lint=line-length
        objects.foreach ((comp) => {
            try {
                SList<ECal.Component> ecal_tasks;
                client.get_objects_for_uid_sync (comp.get_uid (), out ecal_tasks, null);

                ecal_tasks.foreach ((task) => {
                    debug_task (task_list, task);
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

    private void on_objects_removed (E.Source task_list, ECal.Client client, SList<ECal.ComponentId?> cids, TasksRemovedFunc on_tasks_removed) {  // vala-lint=line-length
        debug (@"Received $(cids.length()) removed task(s) for task list '%s'", task_list.dup_display_name ());

        on_tasks_removed (cids);
    }
}
