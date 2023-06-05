/*
* Copyright 2019-2023 elementary, Inc. (https://elementary.io)
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

public class Tasks.Widgets.SourceRow : Gtk.ListBoxRow {
    public E.Source source { get; construct; }

    private static Gtk.CssProvider listrow_provider;

    private Gtk.Grid source_color;
    private Gtk.Image status_image;
    private Gtk.Label display_name_label;
    private Gtk.Stack status_stack;
    private Gtk.Revealer revealer;

    public SourceRow (E.Source source) {
        Object (source: source);
    }

    static construct {
        listrow_provider = new Gtk.CssProvider ();
        listrow_provider.load_from_resource ("io/elementary/tasks/SourceRow.css");
    }

    construct {
        source_color = new Gtk.Grid () {
            valign = Gtk.Align.CENTER
        };

        source_color.add_css_class ("source-color");
        source_color.get_style_context ().add_provider (listrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        display_name_label = new Gtk.Label (source.display_name) {
            halign = Gtk.Align.START,
            hexpand = true,
            margin_end = 9
        };

        status_image = new Gtk.Image () {
            pixel_size = 16
        };
        status_image.get_style_context ().add_provider (listrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var spinner = new Gtk.Spinner () {
            spinning = true,
            tooltip_text = _("Connecting…")
        };

        status_stack = new Gtk.Stack ();
        status_stack.add_named (status_image, "image");
        status_stack.add_named (spinner, "spinner");

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_start = 12,
            margin_end = 6
        };
        box.append (source_color);
        box.append (display_name_label);
        box.append (status_stack);

        revealer = new Gtk.Revealer () {
            reveal_child = true,
            child = box
        };

        child = revealer;
        get_style_context ().add_provider (listrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        build_drag_and_drop ();

        update_request ();
    }

    private void build_drag_and_drop () {
        var drop_target = new Gtk.DropTarget (Type.STRING, Gdk.DragAction.MOVE);
        add_controller (drop_target);

        drop_target.drop.connect (on_drag_drop);
        drop_target.motion.connect (on_drag_enter);
        drop_target.leave.connect (on_drag_leave);
    }

    private Gdk.DragAction on_drag_enter (double x, double y) {
        warning ("Enter");
        var style_context = get_style_context ();
        if (!style_context.has_class ("drop-hover")) {
            style_context.add_class ("drop-hover");
        }

        return Gdk.DragAction.MOVE;
    }

    private void on_drag_leave () {
        warning ("Leave");
        get_style_context ().remove_class ("drop-hover");
    }

    private Gee.HashMultiMap<string, string> received_drag_data;

    private async bool on_drag_drop_move_tasks () throws Error {
        E.SourceRegistry registry = yield Application.model.get_registry ();
        var move_successful = true;

        var source_uids = received_drag_data.get_keys ();
        foreach (var source_uid in source_uids) {
            var src_source = registry.ref_source (source_uid);

            var component_uids = received_drag_data.get (source_uid);
            foreach (var component_uid in component_uids) {
                if (!yield Application.model.move_task (src_source, source, component_uid)) {
                    move_successful = false;
                }
            }
        }
        return move_successful;
    }

    private bool on_drag_drop (GLib.Value value, double x, double y) {
        var uri = (string) value;
        drag_data_received (uri);

        var drop_successful = false;
        var move_successful = false;
        if (uri != null) {
            drop_successful = true;

            on_drag_drop_move_tasks.begin ((obj, res) => {
                try {
                    move_successful = on_drag_drop_move_tasks.end (res);

                } catch (Error e) {
                    var error_dialog = new Granite.MessageDialog (
                        _("Moving task failed"),
                        _("There was an error while moving the task to the desired list."),
                        new ThemedIcon ("dialog-error"),
                        Gtk.ButtonsType.CLOSE
                    );
                    error_dialog.show_error_details (e.message);
                    error_dialog.present ();
                    error_dialog.response.connect (() => {
                        error_dialog.destroy ();
                    });

                }
            });
        }

        return drop_successful;
    }

    private void drag_data_received (string uri) {
        received_drag_data = new Gee.HashMultiMap<string,string> ();

        var uri_scheme = "task://";

        string? source_uid = null;
        string? component_uid = null;

        if (uri.has_prefix (uri_scheme)) {
            var uri_parts = uri.substring (uri_scheme.length).split ("/");

            if (uri_parts.length == 2) {
                source_uid = uri_parts[0];
                component_uid = uri_parts[1];
            }
        }

        if (source_uid == null || component_uid == null) {
            warning ("Can't handle drop data: Unexpected uri format: %s", uri);

        } else if (source_uid == source.uid) {
            debug ("Dropped task onto the same list, so we have nothing to do.");

        } else {
            received_drag_data.set (source_uid, component_uid);
        }
    }

    public void update_request () {
        Tasks.Application.set_task_color (source, source_color);

        display_name_label.label = source.display_name;

        if (source.connection_status == E.SourceConnectionStatus.CONNECTING) {
            status_stack.visible_child_name = "spinner";
        } else {
            status_stack.visible_child_name = "image";

            switch (source.connection_status) {
                case E.SourceConnectionStatus.AWAITING_CREDENTIALS:
                    status_image.icon_name = "dialog-password-symbolic";
                    status_image.tooltip_text = _("Waiting for login credentials");
                    break;
                case E.SourceConnectionStatus.DISCONNECTED:
                    status_image.icon_name = "network-offline-symbolic";
                    status_image.tooltip_text = _("Currently disconnected from the (possibly remote) data store");
                    break;
                case E.SourceConnectionStatus.SSL_FAILED:
                    status_image.icon_name = "security-low-symbolic";
                    status_image.tooltip_text = _("SSL certificate trust was rejected for the connection");
                    break;
                default:
                    status_image.gicon = null;
                    status_image.tooltip_text = null;
                    break;
            }
        }
    }

    public void remove_request () {
        revealer.reveal_child = false;
        GLib.Timeout.add (revealer.transition_duration, () => {
            ((Gtk.ListBox) parent).remove (this);
            destroy ();

            return GLib.Source.REMOVE;
        });
    }
}
