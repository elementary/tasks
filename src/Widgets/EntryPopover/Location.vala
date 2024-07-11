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
    //  private GLib.Cancellable search_cancellable;
    //  private Granite.Widgets.ModeButton location_mode;
    //  private Marker point;


    public Location () {
        Object (
            icon_name: "mark-location-symbolic",
            placeholder: _("Set Location")
        );
    }

    construct {
        //  map_embed = new GtkChamplain.Embed () {
        //      height_request = 140,
        //      width_request = 260
        //  };

        //  point = new Marker ();

        //  var marker_layer = new Champlain.MarkerLayer.full (Champlain.SelectionMode.SINGLE);
        //  marker_layer.add_marker (point);

        //  var map_view = map_embed.champlain_view;
        //  map_view.zoom_level = 10;
        //  map_view.goto_animation_duration = 500;
        //  map_view.add_layer (marker_layer);
        //  map_view.center_on (point.latitude, point.longitude);

        //  var map_frame = new Gtk.Frame (null);
        //  map_frame.add (map_embed);

        //  location_mode = new Granite.Widgets.ModeButton ();
        //  location_mode.append_text (_("Arriving"));
        //  location_mode.append_text (_("Leaving"));

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
        //  box.append (location_mode);
        //  box.append (map_frame);

        popover.child = box;
        //  popover.show.connect (on_popover_show);

        //  notify["value"].connect (on_value_changed);

        //  search_entry.activate.connect (on_search_entry_activate);
        //  location_mode.mode_changed.connect (on_location_mode_changed);
    }

    //  private void on_popover_show () {
    //      search_entry.text = (value == null ? "" : value.postal_address);

    //      if (search_entry.text != null && search_entry.text.strip ().length > 0) {
    //          search_location.begin (search_entry.text);
    //      } else {
    //          // Use geoclue to find approximate location
    //          discover_current_location.begin ();
    //      }
    //  }

    //  private void on_value_changed () {
    //      if (value == null) {
    //          return;
    //      }

    //      var value_has_postal_address = value.postal_address != null && value.postal_address.strip ().length > 0;
    //      if (value_has_postal_address && search_entry.text != value.postal_address) {
    //          search_entry.text = value.postal_address;
    //      }

        //  switch (value.proximity) {
        //      case Tasks.LocationProximity.ARRIVE:
        //          if (location_mode.selected != 0) {
        //              location_mode.selected = 0;
        //          }
        //          break;

        //      default:
        //          if (location_mode.selected != 1) {
        //              location_mode.selected = 1;
        //          }
        //          break;
        //  }

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
    //  }

    //  private void on_search_entry_activate () {
    //      value = Tasks.Location () {
    //          postal_address = search_entry.text,
    //          display_name = search_entry.text,
    //          longitude = 0,
    //          latitude = 0,
    //          accuracy = (value == null ? Geocode.LocationAccuracy.UNKNOWN : value.accuracy),
    //          proximity = (value == null ? Tasks.LocationProximity.DEPART : value.proximity)
    //      };
    //  }

    //  private void on_location_mode_changed () {
    //      var proximity = (value == null ? Tasks.LocationProximity.DEPART : value.proximity);

    //      switch (location_mode.selected) {
    //          case 0: proximity = Tasks.LocationProximity.ARRIVE; break;
    //          case 1: proximity = Tasks.LocationProximity.DEPART; break;
    //          default: break;
    //      }

    //      value = Tasks.Location () {
    //          postal_address = (value == null ? search_entry.text : value.postal_address),
    //          display_name = (value == null ? search_entry.text : value.display_name),
    //          longitude = (value == null ? 0 : value.longitude),
    //          latitude = (value == null ? 0 : value.latitude),
    //          accuracy = (value == null ? Geocode.LocationAccuracy.UNKNOWN : value.accuracy),
    //          proximity = proximity
    //      };
    //  }

    //  private async void search_location (string location) {
    //      if (search_cancellable != null) {
    //          search_cancellable.cancel ();
    //      }
    //      search_cancellable = new GLib.Cancellable ();

    //      var forward = new Geocode.Forward.for_string (location);
    //      try {
    //          forward.set_answer_count (1);
    //          var places = yield forward.search_async (search_cancellable);
    //          foreach (var place in places) {
    //              point.latitude = place.location.latitude;
    //              point.longitude = place.location.longitude;

    //              if (value != null) {
    //                  value.latitude = place.location.latitude;
    //                  value.longitude = place.location.longitude;
    //              }

    //              Idle.add (() => {
    //                  if (search_cancellable.is_cancelled () == false) {
    //                      map_embed.champlain_view.go_to (point.latitude, point.longitude);
    //                  }
    //                  return GLib.Source.REMOVE;
    //              });
    //          }

    //          search_entry.has_focus = true;
    //      } catch (Error error) {
    //          debug (error.message);
    //      }
    //  }

    //  private async void discover_current_location () {
    //      if (search_cancellable != null) {
    //          search_cancellable.cancel ();
    //      }
    //      search_cancellable = new GLib.Cancellable ();

    //      try {
    //          var simple = yield new GClue.Simple ("io.elementary.tasks", GClue.AccuracyLevel.CITY, null);

    //          point.latitude = simple.location.latitude;
    //          point.longitude = simple.location.longitude;

    //          Idle.add (() => {
    //              if (search_cancellable.is_cancelled () == false) {
    //                  map_embed.champlain_view.go_to (point.latitude, point.longitude);
    //              }
    //              return GLib.Source.REMOVE;
    //          });

    //      } catch (Error e) {
    //          warning ("Failed to connect to GeoClue2 service: %s", e.message);
    //          // Fallback to timezone location
    //          search_location.begin (ECal.util_get_system_timezone_location ());
    //      }
    //  }

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
