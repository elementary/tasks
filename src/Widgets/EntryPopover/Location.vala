/*
* Copyright 2021-2023 elementary, Inc. (https://elementary.io)
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

public class Tasks.Widgets.EntryPopover.Location : Generic<Tasks.Location?> {
    //  private GtkChamplain.Embed map_embed;
    private Gtk.SearchEntry search_entry;
    //  private Marker point;
    private GLib.Cancellable search_cancellable;
    private Gtk.ToggleButton arriving_button;
    private Gtk.ToggleButton leaving_button;

    public Location () {
        Object (
            icon_name: "mark-location-symbolic",
            placeholder: _("Set Location")
        );
    }

    construct {
        var registry = new Shumate.MapSourceRegistry.with_defaults ();

        var map = new Shumate.SimpleMap () {
            height_request = 140,
            width_request = 260,
            map_source = registry.get_by_id (Shumate.MAP_SOURCE_OSM_MAPNIK)
        };

        //  point = new Marker ();

        //  var marker_layer = new Champlain.MarkerLayer.full (Champlain.SelectionMode.SINGLE);
        //  marker_layer.add_marker (point);

        //  var map_view = map_embed.champlain_view;
        //  map_view.zoom_level = 10;
        //  map_view.goto_animation_duration = 500;
        //  map_view.add_layer (marker_layer);
        //  map_view.center_on (point.latitude, point.longitude);

        var map_frame = new Gtk.Frame (null) {
            child = map
        };

        arriving_button = new Gtk.ToggleButton.with_label (_("Arriving")) {
            hexpand = true
        };

        leaving_button = new Gtk.ToggleButton.with_label (_("Leaving")) {
            group = arriving_button,
            hexpand = true
        };

        var mode_box = new Gtk.Box (HORIZONTAL, 0);
        mode_box.append (arriving_button);
        mode_box.append (leaving_button);
        mode_box.add_css_class (Granite.STYLE_CLASS_LINKED);

        search_entry = new Gtk.SearchEntry () {
            placeholder_text = _("John Smith OR Example St."),
            hexpand = true
        };

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
            margin_top = 12,
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12
        };

        box.append (search_entry);
        box.append (mode_box);
        box.append (map_frame);

        popover.child = box;
        popover.show.connect (on_popover_show);

        notify["value"].connect (on_value_changed);

        search_entry.activate.connect (on_search_entry_activate);

        arriving_button.toggled.connect (() => {
            if (arriving_button.active) {
                on_location_mode_changed (ARRIVE);
            }
        });

        leaving_button.toggled.connect (() => {
            if (leaving_button.active) {
                on_location_mode_changed (DEPART);
            }
        });
    }

     private void on_popover_show () {
        search_entry.text = (value == null ? "" : value.postal_address);

        if (search_entry.text != null && search_entry.text.strip ().length > 0) {
            search_location.begin (search_entry.text);
        } else {
            // Use geoclue to find approximate location
            discover_current_location.begin ();
        }
     }

     private void on_value_changed () {
        if (value == null) {
            return;
        }

        var value_has_postal_address = value.postal_address != null && value.postal_address.strip ().length > 0;
        if (value_has_postal_address && search_entry.text != value.postal_address) {
            search_entry.text = value.postal_address;
        }

        switch (value.proximity) {
            case Tasks.LocationProximity.ARRIVE:
                if (!arriving_button.active) {
                    arriving_button.active = true;
                }
                break;

            default:
                if (!leaving_button.active) {
                    leaving_button.active = true;
                }
                break;
        }

        //  bool need_relocation = true;
        //  if (value.latitude >= Champlain.MIN_LATITUDE && value.longitude >= Champlain.MIN_LONGITUDE &&
        //      value.latitude <= Champlain.MAX_LATITUDE && value.longitude <= Champlain.MAX_LONGITUDE) {

        //      point.latitude = value.latitude;
        //      point.longitude = value.longitude;

        //      need_relocation = (value.latitude == 0 && value.longitude == 0);
        //  }

        //  if (need_relocation == true) {
        //      if (value_has_postal_address) {
        //          search_location.begin (value.postal_address);
        //      } else {
        //          // Use geoclue to find approximate location
        //          discover_current_location.begin ();
        //      }
        //  }
     }

    private void on_search_entry_activate () {
        value = Tasks.Location () {
            postal_address = search_entry.text,
            display_name = search_entry.text,
            longitude = 0,
            latitude = 0,
            accuracy = (value == null ? Geocode.LocationAccuracy.UNKNOWN : value.accuracy),
            proximity = (value == null ? Tasks.LocationProximity.DEPART : value.proximity)
        };
    }

    private void on_location_mode_changed (Tasks.LocationProximity proximity) {
        value = Tasks.Location () {
            postal_address = (value == null ? search_entry.text : value.postal_address),
            display_name = (value == null ? search_entry.text : value.display_name),
            longitude = (value == null ? 0 : value.longitude),
            latitude = (value == null ? 0 : value.latitude),
            accuracy = (value == null ? Geocode.LocationAccuracy.UNKNOWN : value.accuracy),
            proximity = proximity
        };
    }

    private async void search_location (string location) {
        if (search_cancellable != null) {
            search_cancellable.cancel ();
        }
        search_cancellable = new GLib.Cancellable ();

        var forward = new Geocode.Forward.for_string (location);
        try {
            forward.set_answer_count (1);
            var places = yield forward.search_async (search_cancellable);
            foreach (var place in places) {
                // point.latitude = place.location.latitude;
                // point.longitude = place.location.longitude;

                // if (value != null) {
                //     value.latitude = place.location.latitude;
                //     value.longitude = place.location.longitude;
                // }

                // Idle.add (() => {
                //     if (search_cancellable.is_cancelled () == false) {
                //         map_embed.champlain_view.go_to (point.latitude, point.longitude);
                //     }
                //     return GLib.Source.REMOVE;
                // });
            }

            // search_entry.has_focus = true;
        } catch (Error error) {
            debug (error.message);
        }
    }

    private async void discover_current_location () {
        if (search_cancellable != null) {
            search_cancellable.cancel ();
        }
        search_cancellable = new GLib.Cancellable ();

        try {
            var simple = yield new GClue.Simple ("io.elementary.tasks", GClue.AccuracyLevel.CITY, null);

            // point.latitude = simple.location.latitude;
            // point.longitude = simple.location.longitude;

            // Idle.add (() => {
            //     if (search_cancellable.is_cancelled () == false) {
            //     map_embed.champlain_view.go_to (point.latitude, point.longitude);
            //     }
            //     return GLib.Source.REMOVE;
            // });
        } catch (Error e) {
            warning ("Failed to connect to GeoClue2 service: %s", e.message);
            // Fallback to timezone location
            search_location.begin (ECal.util_get_system_timezone_location ());
        }
    }

    //  private class Marker : Champlain.Marker {
    //      public Marker () {
    //          try {
    //              weak Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default ();
    //              var pixbuf = icon_theme.load_icon ("location-marker", 32, Gtk.IconLookupFlags.GENERIC_FALLBACK);
    //              Clutter.Image image = new Clutter.Image ();
    //              image.set_data (pixbuf.get_pixels (),
    //                            pixbuf.has_alpha ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888,
    //                            pixbuf.width,
    //                            pixbuf.height,
    //                            pixbuf.rowstride);
    //              content = image;
    //              set_size (pixbuf.width, pixbuf.height);
    //              translation_x = -pixbuf.width / 2;
    //              translation_y = -pixbuf.height;
    //          } catch (Error e) {
    //              critical (e.message);
    //          }
    //      }
    //  }
}
