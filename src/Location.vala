/*
 * Copyright 2020-2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public struct Tasks.Location {
    string postal_address;
    string? display_name;

    double longitude;
    double latitude;
    int accuracy;

    Tasks.LocationProximity proximity;
}

public enum Tasks.LocationProximity {
    ARRIVE,
    DEPART;

    public static Tasks.LocationProximity from_string (string val) {
        if (val == "DEPART") {
            return Tasks.LocationProximity.DEPART;
        } else {
            return Tasks.LocationProximity.ARRIVE;
        }
    }

    public unowned string to_string () {
        switch (this) {
            case Tasks.LocationProximity.DEPART:
                return "DEPART";
            case Tasks.LocationProximity.ARRIVE:
            default:
                return "ARRIVE";
        }
    }
}
