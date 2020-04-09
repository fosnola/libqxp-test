#!/usr/bin/perl

use settings;

my $do_odf = 0;     # execute the odf diff test
my $do_vg = 0;      # execute the valgrind test (takes a while)

sub VgTest
{
    my ($command, $path, $faileds) = @_;

    $vgPath = $path . 'vg';
    my $failed = 0;
    `valgrind --tool=memcheck --leak-check=yes $command $path 1> $vgPath 2> $vgPath`;
    open VG, "$vgPath";
    my $vgOutput;
    while (<VG>)
    {
        if (/^\=\=/)
        {
            $vgOutput .= $_;
            if (/definitely lost: [1-9]/ || /ERROR SUMMARY: [1-9]/ || /Invalid read of/)
            {
                $failed = 1;
            }
        }
    }
    close VG;

    `rm -f $vgPath`;
    if ($failed)
    {
        open VG, ">$vgPath";
        print VG $vgOutput;
        close VG;
        ${$faileds}++;
    }
    $vgOutput = "";

    print "! $file odf valgrind: " . ($failed ? "failed" : "passed") . "\n";
}

sub DiffTest
{
    my ($command, $command2, $file, $extension) = @_;
    my $result = "passed";
    my $comment = "";

    my $errPath = $file . ".$extension.err";
    my $rawPath = $file . ".$extension";
    my $newRawPath = $file . ".$extension.new";
    my $diffPath = $file . ".$extension.diff";

    # generate a new raw output to compare with
    `$command $file 1> $newRawPath`;
    if ($command2)
    {
        `mv $newRawPath $newRawPath.tmp`;
        `$command2 $newRawPath.tmp 1> $newRawPath`;
        `rm $newRawPath.tmp`;
    }

    # HACK: check if there is a raw file with _some_ contents. If not, we've had a segfault
    my $err = "";
    my $diff = "";
    $newRaw=`cat $newRawPath`;
    if ($newRaw eq "")
    {
        $err = "Segmentation fault";
        `echo $err > $errPath`;
    }

    if ($err ne "")
    {
        $result = "fail";
    }
    else
    {
        # remove the generated (empty) error file
        `rm -f $errPath`;

        # diff the stored raw data with the newly generated raw data
        `diff -u -b $rawPath $newRawPath 1>$diffPath 2>$diffPath`;
#    print "DEBUG: $extension fp:$file ep:$errPath rp:$rawPath nrp:$newRawPath dp:$diffPath\n";
        $diff=`cat $diffPath | grep -v "No differences encountered"`;

        if ($diff ne "")
        {
            $result = "changed";
        }
        else
        {
            `rm -f $diffPath`;
        }
    }

    # remove the generated raw file
    `rm -f $newRawPath`;

    # DISPLAYING RESULTS
    if ($err ne "" || $diff ne "")
    {
        $comment = ($err ne "" ? "(error: " : "(diff: ") . ($err ne "" ? $errPath : $diffPath) . ")";
    }
    print "! $file diff (using $command): $result $comment\n";

    return $result;
}

sub RegTest
{
    my ($versionList, $tools, $odfExt) = @_;

    my $rawDiffFailures = 0;
    my $svgDiffFailures = 0;
    my $odfDiffFailures = 0;
    my $rawVgFailures = 0;
    my $svgVgFailures = 0;
    my $odfVgFailures = 0;

    my $version;
    foreach $version ( @$versionList )
    {
        print "Regression testing the " . $version . " parser\n";

        my $regrInput = 'testset/' . $version . '/regression.in';

        my @fileList = split(/\n/, `cat $regrInput`);
        foreach $file ( @fileList )
        {
            my $filePath = 'testset/' . $version  . '/' . $file;

            # /////////////////////
            # DIFF REGRESSION TESTS
            # /////////////////////

            if (DiffTest($tools->{'raw'}, 0, $filePath, "raw") eq "fail")
            {
                $rawDiffFailures++;
            }

            if ($tools->{'svg'})
            {
                if (DiffTest($tools->{'svg'}, "xmllint --format --noblanks", $filePath, "xhtml") eq "fail")
                {
                    $svgDiffFailures++;
                }
            }

            if ($do_odf)
            {
                if (DiffTest($tools->{'odf'}, "xmllint --format --noblanks", $filePath, $odfExt) eq
             "fail")
                {
                    $odfDiffFailures++;
                }
            }
            else
            {
                print "! $file ODG: skipped\n";
            }

            # ////////////////////////////
            # RAW VALGRIND REGRESSION TEST
            # ////////////////////////////
            if ($do_vg)
            {
                VgTest(${tools}->{'raw'}, $filePath . '.raw.vg', \$rawVgFailures);
            }
            else
            {
                print "! $file valgrind: skipped\n";
            }

            # ////////////////////////////
            # SVG VALGRIND REGRESSION TEST
            # ////////////////////////////
            if ($do_vg)
            {
                VgTest(${tools}->{'svg'}, $filePath . '.xhtml.vg', \$svgVgFailures);
            }
            else
            {
                print "! $file valgrind: skipped\n";
            }

            # //////////////////////////////////////
            # WRITERPERFECT VALGRIND REGRESSION TEST
            # //////////////////////////////////////

            if ($do_vg && $do_odf)
            {
                VgTest(${tools}->{'odf'}, $filePath . ${odfExt} . '.vg', \$odfVgFailures);
            }
            else
            {
                print "! $file odf valgrind: skipped\n";
            }
        }
    }

    print "\nSummary\n";
    print "Regression test found " . $rawDiffFailures . " raw diff failure(s)\n";
    print "Regression test found " . $svgDiffFailures . " svg diff failure(s)\n";
    if ($do_odf)
    {
        print "Regression test found " . $odfDiffFailures . " odf diff failure(s)\n";
    }
    else
    {
        print "Odg test skipped\n";
    }

    if ($do_vg)
    {
        print "Regression test found " . $rawVgFailures . " raw valgrind failure(s)\n";
    }
    else
    {
        print "Raw valgrind test skipped\n";
    }

    if ($do_vg)
    {
        print "Regression test found " . $svgVgFailures . " svg valgrind failure(s)\n";
    }
    else
    {
        print "Svg valgrind test skipped\n";
    }

    if ($do_vg && $do_odf)
    {
        print "Regression test found " . $odfVgFailures . " odf valgrind failure(s)\n";
    }
    else
    {
        print "Odg valgrind test skipped\n";
    }
}

my $confused = 0;
while (scalar(@ARGV) > 0)
{
    my $argument = shift @ARGV;
    if ($argument =~ /--vg/)
    {
        $do_vg = 1;
    }
    elsif ($argument =~ /--odf/)
    {
        $do_odf = 1;
    }
    else
    {
        $confused = 1;
    }
}
if ($confused)
{
    print "Usage: regression.pl [ --vg ] [ --odf ]\n";
    exit;
}

# Main function

RegTest(\@settings::versionList, \%settings::tools, 'fodg');

# vim: set ts=4 sw=4 et:
