public class Tasks.ListSettingsPopover : Gtk.Popover {
    private Gtk.Entry name_entry;

    private E.SourceTaskList task_list;

    private Gtk.RadioButton color_button_red;
    private Gtk.RadioButton color_button_orange;
    private Gtk.RadioButton color_button_yellow;
    private Gtk.RadioButton color_button_green;
    private Gtk.RadioButton color_button_blue;
    private Gtk.RadioButton color_button_purple;
    private Gtk.RadioButton color_button_brown;
    private Gtk.RadioButton color_button_slate;
    private Gtk.RadioButton color_button_none;

    public E.Source _source;
    public E.Source source {
        set {
            _source = value;
            
            name_entry.text = _source.dup_display_name ();
            name_entry.sensitive = _source.writable;

            task_list = ((E.SourceTaskList?) _source.get_extension (E.SOURCE_EXTENSION_TASK_LIST));
            switch (task_list.dup_color ()) {
                case "#c6262e":
                    color_button_red.active = true;
                    break;
                case "#f37329":
                    color_button_orange.active = true;
                    break;
                case "#e6a92a":
                    color_button_yellow.active = true;
                    break;
                case "#68b723":
                    color_button_green.active = true;
                    break;
                case "#3689e6":
                    color_button_blue.active = true;
                    break;
                case "#a56de2":
                    color_button_purple.active = true;
                    break;
                case "#8a715e":
                    color_button_brown.active = true;
                    break;
                case "#667885":
                    color_button_slate.active = true;
                    break;
                default:
                    color_button_none.active = true;
                    break;
            }
        }

        get {
            return _source;
        }
    }

    public ListSettingsPopover () {}

    construct {
        modal = true;
        position = Gtk.PositionType.BOTTOM;
        
        var name_label = new Granite.HeaderLabel (_("Name:"));

        name_entry = new Gtk.Entry ();
        name_entry.activates_default = true;

        var css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("/io/elementary/tasks/ColorButton.css");

        var color_label = new Granite.HeaderLabel (_("Color:"));

        color_button_red = new Gtk.RadioButton (null);

        unowned Gtk.StyleContext color_button_red_context = color_button_red.get_style_context ();
        color_button_red_context.add_class ("color-button");
        color_button_red_context.add_class ("red");
        color_button_red_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        color_button_orange = new Gtk.RadioButton.from_widget (color_button_red);

        unowned Gtk.StyleContext color_button_orange_context = color_button_orange.get_style_context ();
        color_button_orange_context.add_class ("color-button");
        color_button_orange_context.add_class ("orange");
        color_button_orange_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        color_button_yellow = new Gtk.RadioButton.from_widget (color_button_red);

        unowned Gtk.StyleContext color_button_yellow_context = color_button_yellow.get_style_context ();
        color_button_yellow_context.add_class ("color-button");
        color_button_yellow_context.add_class ("yellow");
        color_button_yellow_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        color_button_green = new Gtk.RadioButton.from_widget (color_button_red);

        unowned Gtk.StyleContext color_button_green_context = color_button_green.get_style_context ();
        color_button_green_context.add_class ("color-button");
        color_button_green_context.add_class ("green");
        color_button_green_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        color_button_blue = new Gtk.RadioButton.from_widget (color_button_red);

        unowned Gtk.StyleContext color_button_blue_context = color_button_blue.get_style_context ();
        color_button_blue_context.add_class ("color-button");
        color_button_blue_context.add_class ("blue");
        color_button_blue_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        color_button_purple = new Gtk.RadioButton.from_widget (color_button_red);

        unowned Gtk.StyleContext color_button_purple_context = color_button_purple.get_style_context ();
        color_button_purple_context.add_class ("color-button");
        color_button_purple_context.add_class ("purple");
        color_button_purple_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        color_button_brown = new Gtk.RadioButton.from_widget (color_button_red);

        unowned Gtk.StyleContext color_button_brown_context = color_button_brown.get_style_context ();
        color_button_brown_context.add_class ("color-button");
        color_button_brown_context.add_class ("brown");
        color_button_brown_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        color_button_slate = new Gtk.RadioButton.from_widget (color_button_red);

        unowned Gtk.StyleContext color_button_slate_context = color_button_slate.get_style_context ();
        color_button_slate_context.add_class ("color-button");
        color_button_slate_context.add_class ("slate");
        color_button_slate_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        color_button_none = new Gtk.RadioButton.from_widget (color_button_red);

        var color_grid = new Gtk.Grid ();
        color_grid.column_spacing = 6;
        color_grid.add (color_button_red);
        color_grid.add (color_button_orange);
        color_grid.add (color_button_yellow);
        color_grid.add (color_button_green);
        color_grid.add (color_button_blue);
        color_grid.add (color_button_purple);
        color_grid.add (color_button_brown);
        color_grid.add (color_button_slate);

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.margin = 12;
        grid.margin_top = 3;
        grid.add (name_label);
        grid.add (name_entry);
        grid.add (color_label);
        grid.add (color_grid);
        
        add (grid);
        grid.show_all ();

        color_button_red.toggled.connect (() => {
            task_list.color = "#c6262e";
            save ();
        });

        color_button_orange.toggled.connect (() => {
            task_list.color = "#f37329";
            save ();
        });

        color_button_yellow.toggled.connect (() => {
            task_list.color = "#e6a92a";
            save ();
        });

        color_button_green.toggled.connect (() => {
            task_list.color = "#68b723";
            save ();
        });

        color_button_blue.toggled.connect (() => {
            task_list.color = "#3689e6";
            save ();
        });

        color_button_purple.toggled.connect (() => {
            task_list.color = "#a56de2";
            save ();
        });

        color_button_brown.toggled.connect (() => {
            task_list.color = "#8a715e";
            save ();
        });

        color_button_slate.toggled.connect (() => {
            task_list.color = "#667885";
            save ();
        });

        name_entry.changed.connect (save);
    }

    private void save () {
        _source.display_name = name_entry.text;
        _source.write.begin (null);
    }
}