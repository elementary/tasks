project('io.elementary.tasks', 'vala', 'c')

gnome = import('gnome')
i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')
add_project_arguments(['--vapidir', join_paths(meson.current_source_dir(), 'vapi')], language: 'vala')

gresource = gnome.compile_resources(
    'gresource',
    join_paths('data', 'gresource.xml'),
    source_dir: 'data'
)

add_project_arguments('-DLIBICAL_GLIB_UNSTABLE_API=1', language: 'c')

executable(
    meson.project_name(),
    gresource,
    'src/Application.vala',
    'src/ListView.vala',
    'src/MainWindow.vala',
    'src/EDS/EDS.vala',
    'src/EDS/ICalTime.vala',
    'src/EDS/TaskStore.vala',
    'src/Util.vala',
    'src/Widgets/EditableLabel.vala',
    'src/Widgets/ScheduledRow.vala',
    'src/Widgets/SourceRow.vala',
    'src/Widgets/TaskRow.vala',
    'src/Widgets/ListSettingsPopover.vala',
    dependencies: [
        dependency('glib-2.0'),
        dependency('gobject-2.0'),
        dependency('granite', version: '>=0.5'),
        dependency('gtk+-3.0'),
        dependency('libecal-2.0'),
        dependency('libedataserver-1.2'),
        dependency('libhandy-1', version: '>=0.90.0'),
        dependency('libical-glib')
    ],
    install : true
)

subdir('data')
subdir('po')

meson.add_install_script('meson/post_install.py')
