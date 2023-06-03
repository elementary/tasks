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

public class Tasks.Widgets.EntryPopover.Tag : Generic<string?> {

    /**
    We should make use of the available category management functions from EDS here:

    - https://valadoc.org/libedataserver-1.2/E.categories_add.html
    - https://valadoc.org/libedataserver-1.2/E.categories_dup_icon_file_for.html
    - https://valadoc.org/libedataserver-1.2/E.categories_dup_list.html
    - https://valadoc.org/libedataserver-1.2/E.categories_exist.html
    - https://valadoc.org/libedataserver-1.2/E.categories_is_searchable.html
    - https://valadoc.org/libedataserver-1.2/E.categories_register_change_listener.html
    - https://valadoc.org/libedataserver-1.2/E.categories_remove.html
    - https://valadoc.org/libedataserver-1.2/E.categories_set_icon_file_for.html
    - https://valadoc.org/libedataserver-1.2/E.categories_unregister_change_listener.html
    */

    public Tag () {
        Object (
            icon_name: "folder-tag-symbolic",
            placeholder: _("Select Tags")
        );
    }

    construct {
        var grid = new Gtk.Grid () {
            margin_top= 3
        };
        grid.show_all ();

        popover.add (grid);

        popover.show.connect (on_popover_show);
    }

    private void on_popover_show () {
        var available_categories = E.categories_dup_list ();
        available_categories.foreach((category) => {
            debug ("Available Category: %s", category);
        });
    }
}
