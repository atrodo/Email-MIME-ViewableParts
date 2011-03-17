use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Email::MIME::ViewableParts',
    AUTHOR              => 'Jon Gentle <atrodo@atrodo.org>',
    VERSION_FROM        => 'lib/Email/MIME/ViewableParts.pm',
    ABSTRACT_FROM       => 'lib/Email/MIME/ViewableParts.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Email::MIME' => 0,
        'Email::MIME::ContentType' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Email-MIME-ViewableParts-*' },
);
