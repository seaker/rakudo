# This script reads the native_array.pm file from STDIN, and generates the
# @PRE[]array, numarray and strarray roles in it, and writes it to STDOUT.

use v6;

my $generator = $*PROGRAM-NAME;
my $generated = DateTime.now.gist.subst(/\.\d+/,'');
my $start     = '#- start of generated part of ';
my $idpos     = $start.chars;
my $idchars   = 3;
my $end       = '#- end of generated part of ';

# for all the lines in the source that don't need special handling
for $*IN.lines -> $line {

    # nothing to do yet
    unless $line.starts-with($start) {
        say $line;
        next;
    }

    # found header
    my $type = $line.substr($idpos,$idchars);
    die "Don't know how to handle $type" unless $type eq "int" | "num" | "str";
    say $start ~ $type ~ "array role -----------------------------------";
    say "#- Generated on $generated by $generator";
    say "#- PLEASE DON'T CHANGE ANYTHING BELOW THIS LINE";

    # skip the old version of the code
    for $*IN.lines -> $line {
        last if $line.starts-with($end);
    }

    # set up template values
    my @PRE  = $type;
    my @POST = $type.substr(0,1) ~ '(';
    my @values = '@values';
    my @type = $type;
    my @Type = $type.tclc;
    my @i    = '$i';

    # spurt the role
    say Q:a:to/SOURCE/.chomp;

        multi method AT-POS(@PRE[]array:D: int $idx) is raw {
            nqp::atposref_@POST[]self, $idx)
        }
        multi method AT-POS(@PRE[]array:D: Int:D $idx) is raw {
            nqp::atposref_@POST[]self, $idx)
        }

        multi method ASSIGN-POS(@PRE[]array:D: int $idx, @type[] $value) {
            nqp::bindpos_@POST[]self, $idx, $value)
        }
        multi method ASSIGN-POS(@PRE[]array:D: Int:D $idx, @type[] $value) {
            nqp::bindpos_@POST[]self, $idx, $value)
        }
        multi method ASSIGN-POS(@PRE[]array:D: int $idx, @Type[]:D $value) {
            nqp::bindpos_@POST[]self, $idx, $value)
        }
        multi method ASSIGN-POS(@PRE[]array:D: Int:D $idx, @Type[]:D $value) {
            nqp::bindpos_@POST[]self, $idx, $value)
        }
        multi method ASSIGN-POS(@PRE[]array:D: Any $idx, Mu \value) {
            X::TypeCheck.new(
                operation => "assignment to @type[] array element #$idx",
                got       => value,
                expected  => T,
            ).throw;
        }

        multi method STORE(@PRE[]array:D: $value) {
            nqp::bindpos_@POST[]self, 0, nqp::unbox_@POST[]$value));
            self
        }
        multi method STORE(@PRE[]array:D \SELF: @type[] @values[]) {
            nqp::splice(self,@values[],0,0)
        }
        multi method STORE(@PRE[]array:D: @values[]) {
            my int $elems = @values[].elems;
            nqp::setelems(self, $elems);

            my int $i = -1;
            nqp::bindpos_@POST[]self, $i,
              nqp::unbox_@POST[]@values[] .AT-POS(@i[])))
              while nqp::islt_i($i = nqp::add_i($i,1),$elems);
            self
        }

        multi method push(@PRE[]array:D: @type[] $value) {
            nqp::push_@POST[]self, $value);
            self
        }
        multi method push(@PRE[]array:D: @Type[]:D $value) {
            nqp::push_@POST[]self, $value);
            self
        }
        multi method push(@PRE[]array:D: Mu \value) {
            X::TypeCheck.new(
                operation => 'push to @type[] array',
                got       => value,
                expected  => T,
            ).throw;
        }
        multi method append(@PRE[]array:D: @type[] $value) {
            nqp::push_@POST[]self, $value);
            self
        }
        multi method append(@PRE[]array:D: @Type[]:D $value) {
            nqp::push_@POST[]self, $value);
            self
        }
        multi method append(@PRE[]array:D: @type[] @values[]) {
            nqp::splice(self,@values[],nqp::elems(self),0)
        }
        multi method append(@PRE[]array:D: @values[]) {
            fail X::Cannot::Lazy.new(:action<append>, :what(self.^name))
              if @values[].is-lazy;
            nqp::push_@POST[]self, $_) for flat @values[];
            self
        }

        method pop(@PRE[]array:D:) returns @type[] {
            nqp::elems(self) > 0
              ?? nqp::pop_@POST[]self)
              !! die X::Cannot::Empty.new(:action<pop>, :what(self.^name));
        }

        method shift(@PRE[]array:D:) returns @type[] {
            nqp::elems(self) > 0
              ?? nqp::shift_@POST[]self)
              !! die X::Cannot::Empty.new(:action<shift>, :what(self.^name));
        }

        multi method unshift(@PRE[]array:D: @type[] $value) {
            nqp::unshift_@POST[]self, $value);
            self
        }
        multi method unshift(@PRE[]array:D: @Type[]:D $value) {
            nqp::unshift_@POST[]self, $value);
            self
        }
        multi method unshift(@PRE[]array:D: @values[]) {
            fail X::Cannot::Lazy.new(:action<unshift>, :what(self.^name))
              if @values[].is-lazy;
            nqp::unshift_@POST[]self, @values[].pop) while @values[];
            self
        }
        multi method unshift(@PRE[]array:D: Mu \value) {
            X::TypeCheck.new(
                operation => 'unshift to @type[] array',
                got       => value,
                expected  => T,
            ).throw;
        }

        multi method splice(@PRE[]array:D: $offset=0, $size=Whatever, *@values[], :$SINK) {
            fail X::Cannot::Lazy.new(:action('splice in'))
              if @values[].is-lazy;

            my $elems = self.elems;
            my int $o = nqp::istype($offset,Callable)
              ?? $offset($elems)
              !! nqp::istype($offset,Whatever)
                ?? $elems
                !! $offset.Int;
            X::OutOfRange.new(
              :what('Offset argument to splice'),
              :got($o),
              :range("0..$elems"),
            ).fail if $o < 0 || $o > $elems; # one after list allowed for "push"

            my int $s = nqp::istype($size,Callable)
              ?? $size($elems - $o)
              !! !defined($size) || nqp::istype($size,Whatever)
                 ?? $elems - ($o min $elems)
                 !! $size.Int;
            X::OutOfRange.new(
              :what('Size argument to splice'),
              :got($s),
              :range("0..^{$elems - $o}"),
            ).fail if $s < 0;

            if $SINK {
                my @splicees := nqp::create(self);
                nqp::push_@POST[]@splicees, @values[].shift) while @values[];
                nqp::splice(self, @splicees, $o, $s);
                Nil;
            }

            else {
                my @ret := nqp::create(self);
                my int $i = $o;
                my int $n = ($elems min $o + $s) - 1;
                while $i <= $n {
                    nqp::push_@POST[]@ret, nqp::atpos_@POST[]self, $i));
                    $i = $i + 1;
                }

                my @splicees := nqp::create(self);
                nqp::push_@POST[]@splicees, @values[].shift) while @values[];
                nqp::splice(self, @splicees, $o, $s);
                @ret;
            }
        }

        method iterator(@PRE[]array:D:) {
            class :: does Iterator {
                has int $!i;
                has $!array;    # Native array we're iterating

                method !SET-SELF(\array) {
                    $!array := nqp::decont(array);
                    $!i = -1;
                    self
                }
                method new(\array) { nqp::create(self)!SET-SELF(array) }

                method pull-one() is raw {
                    ($!i = $!i + 1) < nqp::elems($!array)
                      ?? nqp::atposref_@POST[]$!array,$!i)
                      !! IterationEnd
                }
                method push-all($target) {
                    my int $i     = $!i;
                    my int $elems = nqp::elems($!array);
                    $target.push(nqp::atposref_@POST[]$!array,$i))
                      while ($i = $i + 1) < $elems;
                    $!i = $i;
                    IterationEnd
                }
            }.new(self)
        }
SOURCE

    # we're done for this role
    say "#- PLEASE DON'T CHANGE ANYTHING ABOVE THIS LINE";
    say $end ~ $type ~ "array role -------------------------------------";
}
