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

public class Tasks.TaskSettingsPopover : Gtk.Popover {

    public Tasks.TaskModel model { get; construct; }

    public TaskSettingsPopover (Tasks.TaskModel model) {
        Object (model: model);
    }

    construct {
        var summary_entry = new Gtk.Entry ();
        summary_entry.text = model.summary;

        var grid = new Gtk.Grid ();
        grid.add (summary_entry);
        grid.show_all ();
        add (grid);
    }
}
