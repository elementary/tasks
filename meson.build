project('io.elementary.tasks', 'vala', 'c')

gnome = import('gnome')
i18n = import('i18n')

add_project_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')
add_project_arguments('-DLIBICAL_GLIB_UNSTABLE_API=1', language: 'c')

gresource = gnome.compile_resources(
    'gresource',
    join_paths('data', 'gresource.xml'),
    source_dir: 'data'
)

add_project_arguments('-DLIBICAL_GLIB_UNSTABLE_API=1', language: 'c')

libecal_dep = dependency('libecal-2.0')

tasks_deps = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('granite', version: '>=0.5'),
    dependency('gtk+-3.0'),
    libecal_dep,
    dependency('libedataserver-1.2'),
    dependency('libhandy-1', version: '>=0.90.0'),
    dependency('libical-glib')
]

if libecal_dep.version().version_compare('<=3.39')
    tasks_deps += meson.get_compiler('vala').find_library('libecal-2.0-fixes', dirs: meson.current_source_dir() / 'vapi')
endif

executable(
    meson.project_name(),
    gresource,
    'src/Application.vala',
    'src/ListView.vala',
    'src/MainWindow.vala',
    'src/Util.vala',
    'src/Widgets/EditableLabel.vala',
    'src/Widgets/ScheduledRow.vala',
    'src/Widgets/SourceRow.vala',
    'src/Widgets/TaskRow.vala',
    'src/Widgets/ListSettingsPopover.vala',
    'src/TaskModel.vala',
    dependencies: tasks_deps,
    install : true
)

subdir('data')
subdir('po')

meson.add_install_script('meson/post_install.py')
