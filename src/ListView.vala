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
    private Gtk.Label summary_label;
    private Gtk.ListBox task_list;

    construct {
        summary_label = new Gtk.Label ("");
        summary_label.halign = Gtk.Align.START;
        summary_label.hexpand = true;
        summary_label.margin_start = 24;

        unowned Gtk.StyleContext summary_label_style_context = summary_label.get_style_context ();
        summary_label_style_context.add_class (Granite.STYLE_CLASS_H1_LABEL);
        summary_label_style_context.add_class (Granite.STYLE_CLASS_ACCENT);

        var list_settings_popover = new Tasks.ListSettingsPopover ();

        var settings_button = new Gtk.MenuButton ();
        settings_button.margin_end = 24;
        settings_button.valign = Gtk.Align.CENTER;
        settings_button.tooltip_text = _("Edit Name and Appearance");
        settings_button.popover = list_settings_popover;
        settings_button.image = new Gtk.Image.from_icon_name ("view-more-horizontal-symbolic", Gtk.IconSize.MENU);
        settings_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        settings_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        task_list = new Gtk.ListBox ();
        task_list.set_filter_func (filter_function);
        task_list.set_sort_func (sort_function);
        task_list.get_style_context ().add_class (Gtk.STYLE_CLASS_BACKGROUND);

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.expand = true;
        scrolled_window.add (task_list);

        margin_bottom = 3;
        column_spacing = 12;
        row_spacing = 24;
        attach (summary_label, 0, 0);
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

        notify["source"].connect (() => {
            foreach (unowned Gtk.Widget child in task_list.get_children ()) {
                child.destroy ();
            }

            if (source != null) {
                update_request ();

                try {
                     var query = "OR (is-completed?) (has-alarms?)";

                     var client = (ECal.Client) ECal.Client.connect_sync (source, ECal.ClientSourceType.TASKS, -1, null);
                     client.get_view_sync (query, out view, null);

                     view.objects_added.connect ((objects) => on_objects_added (source, client, objects));

                     view.start ();

                 } catch (Error e) {
                     critical (e.message);
                 }
            } else {
                summary_label.label = "";
            }

            show_all ();
        });
    }

    public void update_request () {
        summary_label.label = source.dup_display_name ();
        Tasks.Application.set_task_color (source, summary_label);
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

    private void on_objects_added (E.Source source, ECal.Client client, SList<unowned ICal.Component> objects) {
        objects.foreach ((component) => {
            var task_row = new Tasks.TaskRow (component);
            task_list.add (task_row);
        });

        task_list.show_all ();
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
}
