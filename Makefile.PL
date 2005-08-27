use inc::Module::Install;

name           ( 'JSAN-Shell'                 );
abstract       ( 'The JavaScript Archive Network (JSAN) Shell 2' );
author         ( 'Adam Kennedy <cpan@ali.as>' );
version_from   ( 'lib/JSAN/Shell2.pm'         );
license        ( 'perl'                       );
requires       ( 'perl'            => '5.005' );
requires       ( 'Term::ReadLine'  => '1.01'  );
requires       ( 'Getopt::Long'    => '2.34'  );
requires       ( 'JSAN::Client'    => '0.08'  );
build_requires ( 'File::Spec'      => '0.80'  );
build_requires ( 'Test::More'      => '0.47'  );
install_script ( 'bin/jsan2'                  );
auto_install();

&WriteAll;
