use strict;
use warnings;

use inc::Module::Install;

name     'Tapper-MCP';
all_from 'lib/Tapper/MCP.pm';
author   'AMD OSRC Tapper Team <tapper@amd64.org>';
license  'freebsd';

build_requires 'Test::Fixture::DBIC::Schema' => 0;
build_requires 'Test::Perl::Critic'          => 0;
build_requires 'Test::MockModule'            => 0;
build_requires 'Test::More'                  => '0.88';
build_requires 'Tapper::Test' => "3.000010";
build_requires 'Cwd'                         => 0;
build_requires 'String::Diff'                => 0;
build_requires 'File::Spec'                  => 0;

author_requires 'Module::Install::WriteAll';

requires 'perl'                       => '5.010';
#requires 'App::Daemon'                => 0;
requires 'Tapper::Base' => "3.000010";
requires 'Tapper::Config' => "3.000012";
requires 'Tapper::Model' => "3.000010";
requires 'Tapper::Schema' => "3.000014";
requires 'Tapper::Cmd' => "3.000010";
requires 'Data::DPath'                => 0;
requires 'Perl6::Junction'            => 0;
requires 'Carp'                       => 0;
requires 'Data::Dumper'               => 0;
requires 'Devel::Backtrace'           => 0;
requires 'File::Basename'             => 0;
requires 'File::Path'                 => 0;
requires 'File::Path::Tiny'           => 0;
requires 'File::Spec'                 => 0;
requires 'IO::Handle'                 => 0;
requires 'IO::Select'                 => 0;
requires 'IO::Socket::INET'           => 0;
requires 'Log::Log4perl'              => 0;
requires 'Moose'                      => 0;
requires 'MooseX::Declare'            => "0.27";
requires 'MooseX::Traits'             => "0";
#requires 'MooseX::Method::Signatures' => "0.16";
requires 'Net::SSH'                   => 0;
requires 'Net::SCP'                   => 0;
requires 'Net::OpenSSH'               => 0;
requires 'Socket'                     => 0;
requires 'Template'                   => 0;
requires 'YAML'                       => "0.72";
requires 'parent'                     => 0;
requires 'aliased'                    => 0;

install_script glob('bin/*');

repository 'git://github.com/amd/Tapper-MCP.git';
bugtracker 'http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Tapper-MCP';

WriteAll;

