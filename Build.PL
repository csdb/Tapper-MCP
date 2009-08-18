use strict;
use warnings;
use Module::Build;

# stolen from http://search.cpan.org/dist/App-Install/lib/App/Install.pm#Specify_files_to_install

my $build_class = 'Module::Build';
$build_class    = $build_class->subclass(code => <<'HERE'
 sub process_libauto_files {
        system("mkdir -p blib/lib/auto");
        system("cp -ra lib/auto/* blib/lib/auto/");
        system("chmod -R u+w blib/lib/auto/*"); # dirty hack around ./Build dist with wrong perms
 }
HERE
);

my $builder = $build_class->new
    (
     module_name         => 'Artemis::MCP',
     license             => 'restrictive',
     dist_author         => 'OSRC SysInt Team <osrc-sysint@elbe.amd.com>',
     dist_version_from   => 'lib/Artemis/MCP.pm',
     dist_abstract       => 'Automatic testing environment',
     build_requires => {
                        'Test::Fixture::DBIC::Schema' => 0,
                        'Test::MockModule'            => 0,
                        'Test::More'                  => 0,
                        'Artemis::Test'               => '2.010005',
                        'Cwd'                         => 0,
                        'String::Diff'                => 0,
                       },
     requires => {
                  'perl'                       => '5.010',
                  'App::Daemon'                => 0,
                  'Artemis::Config'            => '2.0100031',
                  'Artemis::Model'             => '2.010003',
                  'Artemis::Schema'            => '2.010018',
                  'Artemis::Exception'         => 0,
                  'Carp'                       => 0,
                  'Data::Dumper'               => 0,
                  'Devel::Backtrace'           => 0,
                  'File::Basename'             => 0,
                  'File::Path'                 => 0,
                  'File::Spec'                 => 0,
                  'IO::Handle'                 => 0,
                  'IO::Select'                 => 0,
                  'IO::Socket::INET'           => 0,
                  'Log::Log4perl'              => 0,
                  'Moose'                      => 0,
                  'MooseX::Declare'            => "0.27",
                  'MooseX::Traits'             => "0",
                  #'MooseX::Method::Signatures' => "0.16",
                  'Socket'                     => 0,
                  'YAML'                       => 0,
                  'parent'                     => 0,
                  'aliased'                    => 0,
                 },
     add_to_cleanup      => [ 'Artemis-*' ],
    );

#$builder->add_build_element('libauto');
$builder->create_build_script();

1;
