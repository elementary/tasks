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

namespace Tasks.Util {

    /**
     * Replaces all line breaks with a space and
     * replaces multiple spaces with a single one.
     */
    private GLib.Regex line_break_to_space_regex = null;

    public string line_break_to_space (string str) {
        if (line_break_to_space_regex == null) {
            try {
                line_break_to_space_regex = new GLib.Regex ("(^\\s+|\\s+$|\n|\\s\\s+)");
            } catch (GLib.RegexError e) {
                critical (e.message);
            }
        }

        try {
            return Tasks.Util.line_break_to_space_regex.replace (str, str.length, 0, " ");
        } catch (GLib.RegexError e) {
            warning (e.message);
        }

        return str;
    }

    /*
     * Gee Utility Functions
     */

    /* Returns true if 'a' and 'b' are the same ECal.Component */
    private bool calcomponent_equal_func (ECal.Component a, ECal.Component b) {
        return a.get_id ().equal (b.get_id ());
    }

    public bool esource_equal_func (E.Source a, E.Source b) {
        return a.equal (b);
    }

    public uint esource_hash_func (E.Source source) {
        return source.hash ();
    }

    //-- E.Source --//

    public string get_esource_collection_display_name (E.Source source) {
        var display_name = "";

        try {
            var registry = Tasks.Application.model.get_registry_sync ();
            var collection_source = registry.find_extension (source, E.SOURCE_EXTENSION_COLLECTION);

            if (collection_source != null) {
                display_name = collection_source.display_name;
            } else if (source.has_extension (E.SOURCE_EXTENSION_TASK_LIST)) {
                display_name = ((E.SourceTaskList) source.get_extension (E.SOURCE_EXTENSION_TASK_LIST)).backend_name;
            }

        } catch (Error e) {
            warning (e.message);
        }
        return display_name;
    }

    //--- Date and Time ---//

    /**
     * Converts two datetimes to one TimeType. The first contains the date,
     * its time settings are ignored. The second one contains the time itself.
     */
    public ICal.Time date_time_to_ical (DateTime date, DateTime? time_local, string? timezone = null) {
        var result = new ICal.Time.from_day_of_year (date.get_day_of_year (), date.get_year ());

        if (time_local != null) {
            if (timezone != null) {
                result.set_timezone (ICal.Timezone.get_builtin_timezone (timezone));
            } else {
                result.set_timezone (ECal.util_get_system_timezone ());
            }

            result.set_is_date (false);
            result.set_time (time_local.get_hour (), time_local.get_minute (), time_local.get_second ());
        } else {
            result.set_is_date (true);
            result.set_time (0, 0, 0);
        }

        return result;
    }

    /**
     * Converts the given TimeType to a DateTime.
     */
    private TimeZone timezone_from_ical (ICal.Time date) {
        int is_daylight;
        var interval = date.get_timezone ().get_utc_offset (null, out is_daylight);
        bool is_positive = interval >= 0;
        interval = interval.abs ();
        var hours = (interval / 3600);
        var minutes = (interval % 3600) / 60;
        var hour_string = "%s%02d:%02d".printf (is_positive ? "+" : "-", hours, minutes);

        return new TimeZone (hour_string);
    }

    /**
     * Converts the given TimeType to a DateTime.
     * XXX : Track next versions of evolution in order to convert ICal.Timezone to GLib.TimeZone with a dedicated function…
     */
    public DateTime ical_to_date_time (ICal.Time date) {
        int year, month, day, hour, minute, second;
        date.get_date (out year, out month, out day);
        date.get_time (out hour, out minute, out second);
        return new DateTime (timezone_from_ical (date), year, month,
            day, hour, minute, second);
    }

    /**
     * Compares a {@link GLib.DateTime} to {@link GLib.DateTime.now_local} and returns a location, relative date string.
     * Results appear as natural-language strings like "Today", "Yesterday", "Fri, Apr 17", "Jan 15", "Sep 18 2019".
     *
     * @param date_time a {@link GLib.DateTime} to compare against {@link GLib.DateTime.now_local}
     *
     * @return a localized, relative date string
     */
    public static string get_relative_date (GLib.DateTime date_time) {
        var now = new GLib.DateTime.now_local ();
        var diff = now.difference (date_time);

        if (Granite.DateTime.is_same_day (date_time, now)) {
            return _("Today");
        } else if (Granite.DateTime.is_same_day (date_time.add_days (1), now)) {
            return _("Yesterday");
        } else if (Granite.DateTime.is_same_day (date_time.add_days (-1), now)) {
            return _("Tomorrow");
        } else if (diff < 6 * TimeSpan.DAY && diff > -6 * TimeSpan.DAY) {
            return date_time.format (Granite.DateTime.get_default_date_format (true, true, false));
        } else if (date_time.get_year () == now.get_year ()) {
            return date_time.format (Granite.DateTime.get_default_date_format (false, true, false));
        } else {
            return date_time.format (Granite.DateTime.get_default_date_format (false, true, true));
        }
    }


    //--- X-Property ---//


    public unowned ICal.Property? get_icalcomponent_x_property (ICal.Component ical_component, string x_property_name) {
        return get_ecalpropertybag_x_property (new ECal.ComponentPropertyBag.from_component (ical_component, (property) => {
            return property.isa () == ICal.PropertyKind.X_PROPERTY;
        }), x_property_name);
    }

    public unowned ICal.Property? get_ecalpropertybag_x_property (ECal.ComponentPropertyBag ecal_propertybag, string x_property_name) {
        unowned ICal.Property? property = null;

        var ecal_propertybag_count = ecal_propertybag.get_count ();
        for (int i = 0; i < ecal_propertybag_count; i++) {
            property = ecal_propertybag.get (i);
            if (property.isa () == ICal.PropertyKind.X_PROPERTY && property.get_x_name () == x_property_name) {
                break;
            }
        }
        return property;
    }


    //--- Location ---//


    public Tasks.Location? get_ecalcomponent_location (ECal.Component ecalcomponent) {
        unowned ICal.Component? icalcomponent = ecalcomponent.get_icalcomponent ();

        string? description = icalcomponent.get_location ();
        int accuracy = Geocode.LocationAccuracy.UNKNOWN;
        Tasks.LocationProximity proximity = Tasks.LocationProximity.ARRIVE;
        double longitude, latitude;
        longitude = latitude = 0;

        var geo_property = icalcomponent.get_first_property (ICal.PropertyKind.GEO_PROPERTY);
        if (geo_property != null) {
            var geo = geo_property.get_geo ();
            longitude = geo.get_lon ();
            latitude = geo.get_lat ();
        }

        ICal.Property? apple_proximity_property = null;
        ICal.Property? apple_location_property = null;

        if (ecalcomponent.has_alarms ()) {
            var all_alarms = ecalcomponent.get_all_alarms ();
            foreach (unowned ECal.ComponentAlarm alarm in all_alarms) {
                unowned ECal.ComponentPropertyBag alarm_property_bag = alarm.get_property_bag ();

                if (apple_proximity_property == null) {
                    apple_proximity_property = get_ecalpropertybag_x_property (alarm_property_bag, "X-APPLE-PROXIMITY");
                }

                if (apple_location_property == null) {
                    apple_location_property = get_ecalpropertybag_x_property (alarm_property_bag, "X-APPLE-STRUCTURED-LOCATION");
                }
            }
        }

        if (apple_proximity_property != null) {
            var apple_proximity_property_value = apple_proximity_property.get_value_as_string ();

            if (apple_proximity_property_value != null) {
                proximity = Tasks.LocationProximity.from_string (apple_proximity_property_value);
            }
        }

        debug (">>>>>>>>> X-APPLE-STRUCTURED-LOCATION is available: %i", apple_location_property != null);

        if (apple_location_property != null) {
            debug (">>>>>>>>> X-APPLE-STRUCTURED-LOCATION = %s", apple_location_property.as_ical_string ());
            /*
             * X-APPLE-STRUCTURED-LOCATION;
             *   VALUE=URI;
             *   X-ADDRESS=Via Monte Ceneri 1\\n6802 Rivera\\nSwitzerland;
             *   X-APPLE-RADIUS=100;
             *   X-APPLE-REFERENCEFRAME=1;
             *   X-TITLE=Marco's Home:
             *   geo:46.141813,8.917549
             */
            
            var apple_location_parameter_x_address = apple_location_property.get_parameter_as_string ("X-ADDRESS");
            debug (">>>>>>>>> X-APPLE-STRUCTURED-LOCATION:X-ADDRESS = '%s'", apple_location_parameter_x_address);
            if (apple_location_parameter_x_address != null && apple_location_parameter_x_address.strip () != "") {
                description = ICal.Value.decode_ical_string (apple_location_parameter_x_address);
                if (description != null) {
                    description = description.replace ("\\n", " ");
                }
            }

            debug (">>>>>>>>> X-APPLE-STRUCTURED-LOCATION:VALUE = '%s'", apple_location_property.get_value_as_string ());
            var apple_location_property_geo = apple_location_property.get_geo ();
            if (apple_location_property_geo != null) {
                latitude = apple_location_property_geo.get_lat ();
                longitude = apple_location_property_geo.get_lon ();
            }
        }

        debug (">>>>>>>>> location.description = '%s'", description);

        if (longitude != 0 && latitude != 0 || description != null && description.strip ().length > 0) {
            var location = Tasks.Location () {
                description = description,
                longitude = longitude,
                latitude = latitude,
                accuracy = accuracy,
                proximity = proximity
            };

            if (location.description == null || location.description.strip ().length == 0) {
                try {
                    var place = new Geocode.Reverse.for_location (new Geocode.Location (
                        location.latitude,
                        location.longitude,
                        location.accuracy
                        )).resolve ();
                    location.description = place.location.description;
                } catch (Error e) {
                    warning (e.message);
                }
            }

            return location;
        }
        return null;
    }

    public void set_ecalcomponent_location (ECal.Component ecalcomponent, Tasks.Location? location) {
        unowned ICal.Component? icalcomponent = ecalcomponent.get_icalcomponent ();
        icalcomponent.set_location ("");

        var geo_property_count = icalcomponent.count_properties (ICal.PropertyKind.GEO_PROPERTY);
        for (int i = 0; i < geo_property_count; i++) {
            var remove_prop = icalcomponent.get_first_property (ICal.PropertyKind.GEO_PROPERTY);
            icalcomponent.remove_property (remove_prop);
        }

        if (ecalcomponent.has_alarms ()) {
            var all_alarms = ecalcomponent.get_all_alarms ();
            foreach (unowned ECal.ComponentAlarm alarm in all_alarms) {
                if (null != get_ecalpropertybag_x_property (alarm.get_property_bag (), "X-APPLE-STRUCTURED-LOCATION")) {
                    ecalcomponent.remove_alarm (alarm.get_uid ());
                }
            }
        }

        if (location != null) {
            if (location.description != null) {
                icalcomponent.set_location (location.description);
            }

            var geo_property = new ICal.Property (ICal.PropertyKind.GEO_PROPERTY);
            var geo = new ICal.Geo (location.latitude, location.longitude);
            geo_property.set_geo (geo);
            icalcomponent.add_property (geo_property);

            var location_alarm = new ECal.ComponentAlarm ();
            location_alarm.set_action (ECal.ComponentAlarmAction.DISPLAY);

            var location_alarm_trigger = new ECal.ComponentAlarmTrigger.relative (ECal.ComponentAlarmTriggerKind.RELATIVE_START, new ICal.Duration.null_duration ());
            location_alarm.set_trigger (location_alarm_trigger);

            unowned ECal.ComponentPropertyBag location_alarm_property_bag = location_alarm.get_property_bag ();

            var location_alarm_x_apple_proximity_property = new ICal.Property (ICal.PropertyKind.X_PROPERTY);
            location_alarm_x_apple_proximity_property.set_x_name ("X-APPLE-PROXIMITY");
            location_alarm_x_apple_proximity_property.set_value (new ICal.Value.x (location.proximity.to_string ()));
            location_alarm_property_bag.add (location_alarm_x_apple_proximity_property);


            /*
             * X-APPLE-STRUCTURED-LOCATION;
             *   VALUE=URI;
             *   X-ADDRESS=Via Monte Ceneri 1\\n6802 Rivera\\nSwitzerland;
             *   X-APPLE-RADIUS=100;
             *   X-APPLE-REFERENCEFRAME=1;
             *   X-TITLE=Marco's Home:
             *   geo:46.141813,8.917549
             */
            var location_alarm_x_apple_structured_location_property = new ICal.Property (ICal.PropertyKind.X_PROPERTY);
            location_alarm_x_apple_structured_location_property.set_x_name ("X-APPLE-STRUCTURED-LOCATION");
            location_alarm_x_apple_structured_location_property.set_parameter_from_string ("VALUE", "URI");
            location_alarm_x_apple_structured_location_property.set_parameter_from_string ("X-ADDRESS", location.description);
            location_alarm_x_apple_structured_location_property.set_parameter_from_string ("X-APPLE-RADIUS", "100");
            location_alarm_x_apple_structured_location_property.set_parameter_from_string ("X-APPLE-REFERENCEFRAME", "1");
            location_alarm_x_apple_structured_location_property.set_parameter_from_string ("X-TITLE", location.description);
            location_alarm_x_apple_structured_location_property.set_value (new ICal.Value.geo (new ICal.Geo (location.latitude, location.longitude)));
            location_alarm_property_bag.add (location_alarm_x_apple_structured_location_property);

            ecalcomponent.add_alarm (location_alarm);
        }
    }
}
