#!/usr/bin/env raku

# This helper script is intended to make adding leap seconds to the
# Raku system as easy as possible: by just giving the date for which
# to add the leap second, it will scan the file for current leap
# second information and add leap second information for that date
# to the source, and update the source-file.

sub MAIN(
  #| the date for which to add a leap second
  Str $the-date,
  #| the source file containing leap second logic (default: src/core.c/Rakudo/Internals.rakumod)
  $the-source = 'src/core.c/Rakudo/Internals.rakumod'
) {

    # set up the new leap second info
    my $date     = Date.new($the-date);
    my $epoch    = $date.DateTime.posix;
    my $before   = $date.earlier(:1day);
    my $daycount = $date.daycount;

    # run through the source file and update as appropriate
    my str @lines;
    for $the-source.IO.lines(:!chomp) -> $line {
        @lines.push: "        '$before',\n"
          if $line eq "        #END leap-second-dates\n";
        @lines.push: "        $epoch,\n"
          if $line eq "        #END leap-second-posix\n";
        @lines.push: "        $daycount,\n"
          if $line eq "        #END leap-second-daycount\n";
        @lines.push: $line;
    }

    spurt $the-source, @lines.join;
}

# vim: expandtab shiftwidth=4
