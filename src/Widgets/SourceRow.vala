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

public class Tasks.SourceRow : Gtk.ListBoxRow {
    public E.Source source { get; construct; }

    private static Gtk.CssProvider listrow_provider;

    private Gtk.Image status_image;
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
        var source_color = new Gtk.Grid ();
        source_color.valign = Gtk.Align.CENTER;

        unowned Gtk.StyleContext source_color_context = source_color.get_style_context ();
        source_color_context.add_class ("source-color");
        source_color_context.add_provider (listrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        Tasks.Application.set_task_color (source, source_color);

        var label = new Gtk.Label (source.display_name);
        label.halign = Gtk.Align.START;
        label.hexpand = true;
        label.margin_end = 9;

        status_image = new Gtk.Image ();
        status_image.pixel_size = 16;
        status_image.get_style_context ().add_provider (listrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var spinner = new Gtk.Spinner ();
        spinner.active = true;
        spinner.tooltip_text = _("Connecting…");

        status_stack = new Gtk.Stack ();
        status_stack.add_named (status_image, "image");
        status_stack.add_named (spinner, "spinner");

        var grid = new Gtk.Grid ();
        grid.column_spacing = 3;
        grid.margin_start = 12;
        grid.margin_end = 6;
        grid.add (source_color);
        grid.add (label);
        grid.add (status_stack);

        revealer = new Gtk.Revealer ();
        revealer.reveal_child = true;
        revealer.add (grid);

        add (revealer);

        update_status_image ();
        source.notify["connection-status"].connect (() => update_status_image);

        var task_list_model = TaskListModel.get_default ();
        task_list_model.tasks_added.connect ((source, tasks) => {
            if( source != this.source ){
                return;
            }
            on_tasks_added (tasks);
        });

        task_list_model.tasks_updated.connect ((source, tasks) => {
            if( source != this.source ){
                return;
            }
            on_tasks_updated (tasks);
        });

        task_list_model.tasks_removed.connect ((source, tasks) => {
            if( source != this.source ){
                return;
            }
            on_tasks_removed (tasks);
        });
    }

    public void remove_request () {
        revealer.reveal_child = false;
        GLib.Timeout.add (revealer.transition_duration, () => {
            destroy ();
            return GLib.Source.REMOVE;
        });
    }

    private void update_status_image () {
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

    private void on_tasks_added (Gee.Collection<ECal.Component> tasks) {
        foreach (var task in tasks) {
            critical("on_tasks_added.task: %s", task.get_summary ().value);
        }
    }

    private void on_tasks_updated (Gee.Collection<ECal.Component> tasks) {
        foreach (var task in tasks) {
            critical("on_tasks_updated.task: %s", task.get_summary ().value);
        }
    }

    private void on_tasks_removed (Gee.Collection<ECal.Component> tasks) {
        foreach (var task in tasks) {
            critical("on_tasks_removed.task: %s", task.get_summary ().value);
        }
    }
}
