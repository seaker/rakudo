# Implementations shared between HyperSeq and RaceSeq.
class Rakudo::Internals::HyperRaceSharedImpl {
    my class Grepper does Rakudo::Internals::HyperProcessor {
        has $!matcher is built;

        method process-batch(Rakudo::Internals::HyperWorkBatch $batch --> Nil) {
            my $items := $batch.items;
            my $elems := nqp::elems($items);
            my &matcher := nqp::istype($!matcher, Callable)
              ?? $!matcher.clone
              !! $!matcher;
            my int $from = -1;
            my int $to   = -1;

            nqp::if(
              nqp::istype(&matcher,Callable)
                && nqp::not_i(nqp::istype(&matcher,Regex)),
              nqp::while(
                nqp::islt_i(++$from,$elems),
                nqp::if(
                  matcher(my $item := nqp::atpos($items,$from)),
                  nqp::bindpos($items,++$to,$item)
                )
              ),
              nqp::while(
                nqp::islt_i(++$from,$elems),
                nqp::if(
                  &matcher.ACCEPTS($item := nqp::atpos($items,$from)),
                  nqp::bindpos($items,++$to,$item)
                )
              )
            );
            nqp::setelems($items,nqp::add_i($to,1))
        }
    }
    multi method grep(\hyper, $source, \matcher, %options) {
        if %options || nqp::istype(matcher, Code) && matcher.count > 1 {
            # Fall back to sequential grep for cases we can't yet handle
            self.rehyper(hyper, hyper.Any::grep(matcher, |%options))
        }
        elsif nqp::istype(matcher,Block) && matcher.has-phasers {
            NYI('Phasers in hyper/race').throw;
        }
        else {
            hyper.bless:
                configuration => hyper.configuration,
                work-stage-head => Grepper.new(:$source, :matcher(matcher))
        }
    }

    my class Mapper does Rakudo::Internals::HyperProcessor {
        has &!mapper is built;

        method process-batch(Rakudo::Internals::HyperWorkBatch $batch --> Nil) {
            my $result := nqp::create(IterationBuffer);
            my $items := $batch.items;
            my int $n = $items.elems;
            my &mapper := &!mapper.clone;
            my int $i = -1;

            nqp::while(
              nqp::islt_i(++$i,$n),
              nqp::if(
                nqp::istype((my \val = mapper(nqp::atpos($items, $i))),Slip)
                  && nqp::not_i(nqp::iscont(val)),
                val.iterator.push-all($result),
                nqp::push($result,val)
              )
            );
            $batch.replace-with($result)
        }
    }
    multi method map(\hyper, $source, &mapper, %options) {
        NYI('Phasers in hyper/race').throw
          if nqp::istype(&mapper,Block) && &mapper.has-phasers;

        if %options || &mapper.count > 1 {
            # Fall back to sequential map for cases we can't yet handle
            self.rehyper(hyper, hyper.Any::map(&mapper, |%options))
        }
        else {
            hyper.bless:
                configuration => hyper.configuration,
                work-stage-head => Mapper.new(:$source, :&mapper)
        }
    }
    multi method invert(\hyper, $source) {
        hyper.bless:
          configuration => hyper.configuration,
          work-stage-head => Mapper.new(:$source,:mapper(-> Pair:D $p {$p.antipair}))
    }

    my class Sinker does Rakudo::Internals::HyperJoiner {
        has Promise $.complete .= new;

        has int $!last-target = -1;
        has int $!batches-seen = 0;
        method consume-batch(Rakudo::Internals::HyperWorkBatch $batch --> Nil) {
            ++$!batches-seen;
            self.batch-used();
            if $batch.last {
                $!last-target = $batch.sequence-number;
            }
            if $!last-target >= 0 && $!batches-seen == $!last-target + 1 {
                $!complete.keep(True);
            }
        }

        method consume-error(Exception $e --> Nil) {
            $!complete.break($e);
        }
    }
    method sink(\hyper, $source --> Nil) {
        if hyper.DEFINITE {
            CATCH {
                unless nqp::istype($_, X::HyperRace::Died) {
                    ($_ but X::HyperRace::Died(Backtrace.new(5))).rethrow
                }
            }
            my $sink = Sinker.new(:$source);
            Rakudo::Internals::HyperPipeline.start($sink, hyper.configuration);
            $*AWAITER.await($sink.complete);
        }
    }

    proto method rehyper($, $) {*}
    multi method rehyper(HyperSeq \hyper, \seq) {
        my \conf = hyper.configuration;
        seq.hyper(:degree(conf.degree), :batch(conf.batch))
    }
    multi method rehyper(RaceSeq \hyper, \seq) {
        my \conf = hyper.configuration;
        seq.race(:degree(conf.degree), :batch(conf.batch))
    }
}

# vim: expandtab shiftwidth=4
