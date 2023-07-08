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

public class Tasks.Application : Gtk.Application {
    const OptionEntry[] OPTIONS = {
        { "background", 'b', 0, OptionArg.NONE, out run_in_background, "Run the Application in background", null},
        { null }
    };

    public static GLib.Settings settings;
    public static Tasks.TaskModel model;
    public static bool run_in_background = false;

    private bool first_activation = true;
    public Application () {
        Object (
            application_id: "io.elementary.tasks",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    static construct {
        settings = new Settings ("io.elementary.tasks");
        model = new Tasks.TaskModel ();
    }

    construct {
        Intl.setlocale (LocaleCategory.ALL, "");
        GLib.Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        GLib.Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        GLib.Intl.textdomain (GETTEXT_PACKAGE);

        add_main_option_entries (OPTIONS);
    }

    protected override void startup () {
        base.startup ();

        unowned var granite_settings = Granite.Settings.get_default ();
        unowned var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == DARK;

        granite_settings.notify["prefers-color-scheme"].connect ((obj) => {
            gtk_settings.gtk_application_prefer_dark_theme = ((Granite.Settings) obj).prefers_color_scheme == DARK;
        });

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (() => {
            if (active_window != null) {
                active_window.destroy ();
            }
        });

        add_action (quit_action);
        set_accels_for_action ("app.quit", {"<Control>q"});

        new Tasks.TodayTaskMonitor ().start.begin ();
    }

    protected override void activate () {
        if (first_activation) {
            first_activation = false;
            hold ();
        }

        if (run_in_background) {
            run_in_background = false;
            request_background.begin ();
            return;
        }

        if (active_window == null) {
            model.start.begin ();

            new MainWindow (this);

            unowned var granite_settings = Granite.Settings.get_default ();
            unowned var gtk_settings = Gtk.Settings.get_default ();

            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

            granite_settings.notify["prefers-color-scheme"].connect (() => {
                gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
            });

            var button_box_style_provider = new Gtk.CssProvider ();
            button_box_style_provider.load_from_resource ("io/elementary/tasks/ButtonBox.css");
            Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), button_box_style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        active_window.present ();
    }

    public async void request_background () {
        var portal = new Xdp.Portal ();

        Xdp.Parent? parent = active_window != null ? Xdp.parent_new_gtk (active_window) : null;

        var command = new GenericArray<weak string> ();
        command.add ("io.elementary.tasks");
        command.add ("--background");

        try {
            if (!yield portal.request_background (
                parent,
                _("Tasks will automatically start when this device turns on and run when its window is closed so that it can send notifications for due tasks."),
                (owned) command,
                Xdp.BackgroundFlags.AUTOSTART,
                null
            )) {
                release ();
            }
        } catch (Error e) {
            if (e is IOError.CANCELLED) {
                debug ("Request for autostart and background permissions denied: %s", e.message);
                release ();
            } else {
                warning ("Failed to request autostart and background permissions: %s", e.message);
            }
        }
    }

    private static Gee.HashMap<string, Gtk.CssProvider>? providers;
    public static void set_task_color (E.Source source, Gtk.Widget widget) {
        if (providers == null) {
            providers = new Gee.HashMap<string, Gtk.CssProvider> ();
        }
        unowned var task_list = (E.SourceTaskList?) source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);
        // Ensure we get a valid CSS color, not including FF
        var color = task_list.dup_color ().slice (0, 7);
        if (!providers.has_key (color)) {
            string style = """
                @define-color colorAccent %s;
                @define-color accent_color %s;
            """.printf (color, color);

            var style_provider = new Gtk.CssProvider ();
            style_provider.load_from_data ((uint8[])style);

            providers[color] = style_provider;
        }

        unowned Gtk.StyleContext style_context = widget.get_style_context ();
        style_context.add_provider (providers[color], Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }

    public static int main (string[] args) {
        var app = new Application ();
        int res = app.run (args);
        ICal.Object.free_global_objects ();
        return res;
    }
}
