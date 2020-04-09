#!/usr/bin/perl

use settings;

sub GenRaw
{
    my ($versionList, $tools, $odfExt) = @_;

    foreach $version ( @$versionList )
    {
        # remove all diff files, since they are possible outdated now
        $diffs = 'testset/' . $version . '/*.diff';
        `rm -f $diffs`;

        $regrInput = 'testset/' . $version . '/regression.in';
        $FL = `cat $regrInput`;

        @fileList = split(/\n/, $FL);
        foreach $file ( @fileList )
        {
            $filePath = 'testset/' . $version  . '/' . $file;
            `$tools->{'raw'} $filePath >$filePath.raw 2>$filePath.raw`;
            my $err = `$tools->{'odf'} --stdout $filePath 2>&1 > $filePath.$odfExt.tmp`;
            if ($err)
            {
                if (open(my $h, '>', "$filePath.err"))
                {
                    print $h $err;
                    close $h;
                }
                else
                {
                    print $err;
                }
            }
            `xmllint --format --noblanks $filePath.$odfExt.tmp > $filePath.$odfExt`;
            `rm $filePath.$odfExt.tmp`;
            if ($tools->{'svg'})
            {
                `$tools->{'svg'} $filePath >$filePath.xhtml.tmp 2>/dev/null`;
                `xmllint --format --noblanks $filePath.xhtml.tmp > $filePath.xhtml`;
                `rm $filePath.xhtml.tmp`;
            }
        }
    }
}

GenRaw(\@settings::versionList, \%settings::tools, 'fodg');

1;

# vim: set ts=4 sw=4 et:
