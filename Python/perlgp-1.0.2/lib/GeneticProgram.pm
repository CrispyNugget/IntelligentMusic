package GeneticProgram;
#GPL#

# TO DO
# per-type numeric mutation probabilities
# perhaps no ignore types
use BaseIndividual;
use Grammar;
use GPMisc;
use Fcntl;
use Digest::MD5 qw(md5_hex);
require SDBM_File;
my $DBTYPE = 'SDBM_File';

@ISA = qw(BaseIndividual);

# for the alarm() calls
use POSIX ':signal_h';
sigaction SIGALRM, new POSIX::SigAction sub { die "alarmed (SigAction handler)" }
  or die "Error setting SIGALRM handler: $!\n";
# which replaces the next line which was unreliable and didn't work with 5.8.0
# actually the new SigAction stuff also causes panic: leave_scope inconsistency.
# but install the handler the old way for versions < 5.8.0
$SIG{ALRM} = sub { die "alarmed (\$SIG{ALRM} handler)" } if ($] < 5.008);


# to prevent deep recursion warnings during _tree_type_size
# and _fix_nodes and _crossover with deep trees
$SIG{__WARN__} = sub { print STDERR @_ unless "@_" =~ /Deep recursion/; };

# a constant
my $too_many_tries = 5000;


sub _init {
  my ($self, %p) = @_;

 #################################################################
 # Paramater defaults, do not change them here, change the ones  #
 # you need in classes inheriting from this (e.g. Individual.pm) #
 #################################################################

  my %defaults = (

 ###### MUTATION ######
 # Probabilty that each node is mutated
		  NodeMutationProb => 1/100,
 # Or you can override this with a fixed number of mutations (beware bloat!)
 # and probability of this happening
                  FixedMutations => 0,
                  FixedMutationProb => 0,

 # Fraction of point mutations (the rest are macro mutations)
		  PointMutationFrac => 0.7,

 # Fraction of point mutations which involve constants that are randomly
 # adjusted rather than discretely
		  NumericMutationFrac => 0.0,
 # Which types are allowed or ignored when doing numeric mutation
 # (for example you might not want some integers becoming floating point)
 # specify the following like this: { VARX=>1, CONSTY=>1 }
		  NumericIgnoreNTypes => {},
 # and/or the following like this: { VARX=>0.5, CONSTY=>0.2 }
 # where the value is the maximum change amount (*= or /= 1.5 and 1.2)
 # default is 0.1 (num = num*1.1 or num = num/1.1)
		  NumericAllowNTypes => {},
 # the regular expression that defines what a number for numeric mutation is
 # for example you could set this to integers only: qr/^\d+$/ so that you
 # get 'one shot' numeric mutation
		  NumericMutationRegex =>
		  qr/^[+-]?\d+(?:\.\d+)?([eE][+-]?\d+)?$/,

 # When set, require that all mutations make some visible difference to code
		  NoNeutralMutations => 0,

 ### Depth bias: zero means no bias, just pick a random node
 ### higher numbers mean that the nodes closer to the root are favoured
 # Depth bias for point mutations
		  PointMutationDepthBias => 0,
 # Depth bias for macro mutations
		  MacroMutationDepthBias => 0.7,

 # What types of macro mutation are used
 # (you can bias certain types by specifying them more than once)
 # 'encapsulate_subtree' and 'point_mutate_deep' are not used by default
		  MacroMutationTypes => [ qw(swap_subtrees copy_subtree
                                             replace_subtree insert_internal
                                             delete_internal) ],

 # If using 'encapsulate_subtree', don't encapsulate subtrees with these
 # node types (specify node types as keys, e.g. { NUM=>1, SUB=>1 })
		  EncapsulateIgnoreNTypes => {},
 # Maximum number of nodes allowed to encapsulate (fraction of total nodes)
		  EncapsulateFracMax => 0.25,
 # Probability that already encapsulated subtrees are used during
 # tree generation as functions or terminals (can make too-small trees)
		  UseEncapsTerminalsFrac => 0.0,

 # Logging mutation data to a file
		  MutationLogFile => 'results/mutation.log',
		  MutationLogProb => 1/50,

 ###### CROSSOVER ######
 # Per-node crossover-point selection probability
		  NodeXoverProb => 1/50,
 # Or you can override this with a fixed number of crossovers (beware bloat!)
 # and probability of this happening
		  FixedXovers => 0,
		  FixedXoverProb => 0,

 ### Crossover bias.  small (say 0.01) -> little bias
 ###                  large (say 10)   -> a lot of bias
 # Bias towards subtrees of the same size
		  XoverSizeBias => 1,
 # Bias towards subtrees with similar contents (by crude identity measure)
		  XoverHomologyBias => 1,
 # Quick Homologous Crossover (new in version 1.1)
 # 0 = off, 1 = always on
                  QuickXoverProb => 0,


 # Depth bias for crossover point selection (see MacroMutationDepthBias)
		  XoverDepthBias => 0.1,

 # Only do asexual reproduction (simple copy of genomes)
		  AsexualOnly => 0,

 # Logging crossover data to a file
		  XoverLogFile => 'results/crossover.log',
		  XoverLogProb => 1/50,


 ###### Tree/subtree size/shape parameters
 # Maximum number of nodes allowed in tree as a whole
 # (random terminal nodes are used after this limit is reached)
		  MaxTreeNodes => 1000,
 # Minimum number of nodes for FRESHLY generated trees (_init_tree())
 # If the tree is too small, it will try again, until the tree is big enough.
 # So this could TAKE TIME...
                  MinTreeNodes => 0,

 ### The following five tree depth options must be changed if
 ### non-naturally terminating grammars are used
 # Maximum allowed depth of *new* trees or subtrees
		  TreeDepthMax => 20,
 # Probability that a terminal node is added during tree or subtree generation
		  TerminateTreeProb => 0,
 # Minimum depth before "TerminateTreeProb" takes effect
		  TreeDepthMin => 1,
 # Mean and maximum (cap) of Poisson distribution of new subtree depths
		  NewSubtreeDepthMean => 20,
		  NewSubtreeDepthMax => 20,

 # During new tree/subtree generation, force a certain fraction
 # of terminals to come only from existing terminals in the tree
 # (possibly useful if you're using numeric mutation)
		  UseExistingTerminalsFrac => 0.0,

 ###### Grammar ######
 # These should be defined in Grammar.pm in the experiment directory
		  Functions => \%Grammar::F,
		  Terminals => \%Grammar::T,

 ###### Other things ######
 # Tells the getSize() method to ignore all nodes below nodes of types
 # specified (in the form { NTYPEX=>1, NTYPEY=>1 })
 # can be useful if your fitness function uses the size of the tree
		  GetSizeIgnoreNTypes => {},

 # if there's a syntax or other error in your evolved
 # subroutines, then PerlGP will sleep for a while before
 # reinitialising that individual.
 # set this to zero if you know what you're doing!
		  SleepAfterSubEvalError => 15,

		 );

  $self->SUPER::_init(%defaults, %p);

  $self->compulsoryParams(qw(DBFileStem Functions Terminals));
  #debug system "touch $self->{DBFileStem}.foo $self->{DBFileStem}.bar";

  # $self->reInitialise(); # is this really necessary?
}


sub reInitialise {
  my $self = shift;

  $self->evalEvolvedSubs();
  $self->evolvedInit();
}

# you MUST override this method in your evolved code (in Grammar.pm)
# $input is the training or testing data structure
sub evaluateOutput {
  my ($self, $input) = @_;
  my $output = 'can be a scalar value or reference to data structure';
  return $output;
}

# you can override this method in your evolved code
# to give you evolvable parameters, for example
sub evolvedInit {
  my $self = shift;
  return;
}

# you can override this method to give info (like evolved params)
# which is used (at least) for the tournament log
sub extraLogInfo {
  my $self = shift;
  return $self->DBFileStem();
}


# tie the hash $self->{genome} to the file on disk
# return pointer to hash
# you must use an equal number of tieGenome and untieGenome !!
# nested tieGenomes are ignored using a depth counting system
sub tieGenome {
  my ($self, $debug) = @_;
  unless ($self->{tie_level}) {
    # warn "tie $debug\n" if ($debug);
    $self->{genome} = {};
    tie %{$self->{genome}},
      $DBTYPE, $self->{DBFileStem}, O_RDWR | O_CREAT, 0644;
    # completely initialise tree if the hash wasn't untied properly (see below)
    $self->_init_tree()
      if (defined $self->{genome}{'tied'} && $self->{genome}{'tied'});
    $self->{genome}{'tied'} = 1;
  }
  $self->{tie_level}++;
  return $self->{genome};
}

# rewrite the hash back to disk (optimises space usage)
sub retieGenome {
  my $self = shift;
  my $genome = $self->tieGenome('retie');
  my %oldgenome = %$genome;
  unlink glob("$self->{DBFileStem}*");
  tie %$genome, $DBTYPE, $self->{DBFileStem}, O_RDWR | O_CREAT, 0644;
  %$genome = %oldgenome;
  $self->untieGenome();
}

sub untieGenome {
  my $self = shift;
  $self->{tie_level}--;
  if ($self->{tie_level} == 0) {
    # this is untying properly (see above)
    $self->{genome}{'tied'} = 0;
    untie %{$self->{genome}};
  }
}

sub _tree_error {
  my ($self, $node, $msg) = @_;
  warn "node $node in genome not found in tree during $msg\n";
  $self->_display_tree('root');
  $self->_init_tree();
  die "died after initialising genome\n";
}

sub initTree {
  my $self = shift;
  $self->tieGenome();
  $self->_init_tree();
  $self->untieGenome();
}

# assume genome is tied
sub _init_tree {
  my $self = shift;
  my $genome = $self->{genome};
  do {
    %{$genome} = ( 'tied'=>1, root=>'{nodeROOT0}', nodeROOT0=>'');
    # it's necessary to set nodeROOT0 twice, believe!
    $genome->{nodeROOT0} =
      $self->_grow_tree(depth=>0,
			TreeDepthMax=>$self->{TreeDepthMax},
			type=>'ROOT');
  } until (keys(%$genome)-2 >= $self->MinTreeNodes());
  # can't use $self->getSize because it does a tie() which can
  # create an endless recursive loop
}

sub initFitness {
  my $self = shift;
  my $genome = $self->tieGenome('initFitness');
  delete $self->{memory}{fitness};
  delete $genome->{fitness};
  $self->untieGenome();
}

sub eraseMemory {
  my $self = shift;
  $self->{memory} = { };
}

sub memory {
  my ($self, @args) = @_;
  if (@args == 1) {
    return $self->{memory}{$arg[0]};
  } elsif (@args % 2 == 0) {
    while (@args) {
      my ($key, $value) = splice @args, 0, 2;
      $self->{memory}{$key} = $value;
    }
  } else {
    die "Individual::memory() called with odd number of elements in hash\n";
  }
}

sub getMemory {
  my ($self, $arg) = @_;
  return $self->memory($arg);
}

sub setMemory {
  my ($self, @args) = @_;
  $self->memory(@args);
}

sub getSize {
  my ($self) = @_;
  my $result;
  my $genome = $self->tieGenome('getSize');
  if ($self->{GetSizeIgnoreNTypes} &&
      keys %{$self->{GetSizeIgnoreNTypes}} && $genome->{root}) {
    $result = $self->_tree_type_size('root', undef, undef,
				     $self->{GetSizeIgnoreNTypes});
  } else {
    $result = scalar grep /^node/, keys %$genome;
  }
  $self->untieGenome();
  return $result;
}

# get and set Fitness routine
# fitness is stored in $self->{fitness} AND $self->{genome}{fitness}
# and some methods in this class access them directly
sub Fitness {
  my ($self, $setval) = @_;
  my $res;
  if (defined $setval) {
    my $genome = $self->tieGenome('setFitness');
    $res = $self->{memory}{fitness} = $genome->{fitness} = $setval;
    $self->untieGenome();
  } else {
    if (defined $self->{memory}{fitness}) { # get quick memory version
      $res = $self->{memory}{fitness};
    } else { # slower disk retrieval
      my $genome = $self->tieGenome('getFitness');
      $res = $genome->{fitness};
      $self->{memory}{fitness} = $res; # set the memory version
      $self->untieGenome();
    }
  }
  return $res;
}

# get or increment Age (age is only stored in memory)
sub Age {
  my ($self, $incr) = @_;
  my $res;
  $self->{memory}{age} = 0 unless (defined $self->{memory}{age});
  if (defined $incr) {
    $res = $self->{memory}{age} += $incr;
  } else {
    $res = $self->{memory}{age};
  }
  return $res;
}

sub getCode {
  my $self = shift;
  my $code = $self->_expand_tree();

  # put the foreach loop before the code or in place of '__loophead__'
  my $loophead = 'foreach $input (@$inputs) {
  undef $output;';
  my $looptail = '  push @results, $output;
}';
  $code =~ s{__loophead__}{$loophead};
  $code =~ s{__looptail__}{$looptail};

  $self->{last_code} = $code;
  return $code;
}

sub evalEvolvedSubs {
  my $self = shift;
  my $code = $self->getCode();
  local $SIG{__WARN__} =
    sub { die @_ unless ($_[0] =~ /Subroutine.+redefined/ ||
			 $_[0] =~ /Attempt to free unreferenced scalar/) };
  eval $code;
  if ($@) {
    print STDERR "$@ during eval of gp subroutines - will reinit after sleep - code follows:\n\n$code";
    sleep $self->SleepAfterSubEvalError(); # because of the recursion!
    $self->initTree(); # so that next time at least the error won't be there
    $self->evalEvolvedSubs();
  }
}

sub _random_terminal {
  my ($self, $type) = @_;
  die "can't find terminal of type $type"
    unless (defined $self->{Terminals}{$type});

  return $self->_random_existing_terminal($type) ||
    GPMisc::pickrandom($self->{Terminals}{$type});
}

sub _random_existing_terminal {
  # assume tied.
  my ($self, $type, $encapsulated) = @_;
  my $prob = $self->{UseExistingTerminalsFrac} || 0;
  $prob = $self->{UseEncapsTerminalsFrac} || 0 if ($encapsulated);
  if ($prob && rand(1) < $prob) {
    my %seenalready;
    my @termnodes = grep {
      /^node$type\d/ &&
	$self->{genome}{$_} &&	# not a null string (or zero)
	  # starts with ;; if encapsulated node requested
	  (!$encapsulated || $self->{genome}{$_} =~ /^;;/) &&
	  $self->{genome}{$_} !~ /\{node[A-Z]+\d+\}/ && # and has no subnodes
	    !$seenalready{$self->{genome}{$_}}++ # just one of each!
                                                 # or nodes can saturate
	  } keys %{$self->{genome}};
    if (@termnodes) {
      my $terminalcopy = GPMisc::pickrandom(\@termnodes);
      $terminalcopy = $self->{genome}{$terminalcopy};
      return $terminalcopy;
    }
  }
  # returns '' if nothing found
  return '';
}

sub _random_function {
  my ($self, $type) = @_;
  if (!defined $self->{Functions}{$type}) {
    return $self->_random_terminal($type);
  } elsif ($self->{UseEncapsTerminalsFrac} &&
	   rand(1) < $self->{UseEncapsTerminalsFrac}) {
    return $self->_random_existing_terminal($type, 'encaps_only') ||
      GPMisc::pickrandom($self->{Functions}{$type});
  } else {
    return GPMisc::pickrandom($self->{Functions}{$type});
  }
}

sub _grow_tree {
  my $self = shift;
  my %p = @_;

  return $self->_random_terminal($p{type})
    if ($p{depth} >= $p{TreeDepthMax} ||
	($p{depth} >= $self->{TreeDepthMin} &&
	 rand()<$self->{TerminateTreeProb}));

  my $node = $self->_random_function($p{type});
  while ($node =~ m/{([A-Z]+)}/g) {
    my $ntype = $1;
    # use random node numbers so that we can do
    # quick homologous crossover
    my $nodeid = $self->nid();
    $nodeid = $self->nid() while (defined $self->{genome}{"node$ntype$nodeid"});
    my $newnode = "node$ntype$nodeid";
    $node =~ s/{$ntype}/{$newnode}/;
    $self->{genome}{$newnode} = '';
    $self->{genome}{$newnode} =
      $self->_grow_tree(depth=>$p{depth}+1,
			TreeDepthMax=>$p{TreeDepthMax}, type=>$ntype);
  }
  return $node;
}

sub nid {
  my $self = shift;
  return int(10*rand($self->{MaxTreeNodes}));
}

sub _expand_tree {
  my ($self, $node) = @_;
  my $genome = $self->tieGenome('expand');
  $node = 'root' unless ($node);

  $self->_init_tree() unless (defined $genome->{$node});

  my $x=0;
  my $maxn = $self->{MaxTreeNodes};
  my $code = $genome->{$node};
  while ($x++<$maxn && $code =~ s/{(node[A-Z]+\d+)}/$genome->{$1}/) {
  }

  if ($x>=$maxn) {
    $code =~ s/{node([A-Z]+)\d+}/$self->_random_terminal($1)/ge;
  }

  # delete encapsulated subtree size prefixes
  $code =~ s/;;\d+;;//g;

  $self->untieGenome();
  return $code;
}

sub crossover {
  my ($self, $mate, $recip1, $recip2) = @_;
  $self->reInitialise(); # if implemented, redefined xover params
  my $mygenome = $self->tieGenome('crossme');
  my $mategenome = $mate->tieGenome('crossmate');

  # how many crossovers will we do?
  my $numtodo = 0;
  unless ($self->FixedXovers()) {
    my $imax = keys %$mygenome;
    for ($i=0; $i<$imax; $i++) {
      $numtodo++ if (rand() < $self->{NodeXoverProb});
    }
  } else {
    $numtodo = $self->FixedXovers()
      if (rand() < $self->FixedXoverProb());

    my $dummy;
    my $imax = keys %$mygenome;
    for ($i=0; $i<$imax; $i++) {
      $dummy++ if (rand() < $self->{NodeXoverProb});
    }
  }

  # recursively determine all subtree sizes and node types for self and mate
  my @mynodes = grep !/ROOT/, grep /^node/, keys %$mygenome;
  my %mysizes; my %mytypes;
  $self->_tree_type_size('root', \%mysizes, \%mytypes);
  my @temp = sort {$b <=> $a} values %mysizes;
  my $mymaxsize = shift @temp;

  my @matenodes = grep !/ROOT/, grep /^node/, keys %$mategenome;
  my %matesizes; my %matetypes;
  $mate->_tree_type_size('root', \%matesizes, \%matetypes);
  @temp = sort {$b <=> $a} values %matesizes;
  my $matemaxsize = shift @temp;

  # now we randomly look through all pairwise combinations of
  # self and mate nodes until the subtree sizes and types match close enough

  my (%myseen, %mateseen);
  my ($samples, $maxsamples, $xovercount) = (0, @mynodes*100, 0);

  my (%myxsubnodes, %matexsubnodes); # these are the children of xover nodes
  my (%myxpair, %matexpair); # these are the xover nodes themselves (value=partners)
  my ($asexual, %pcid); # store the percent ids for logging

  if ($self->{AsexualOnly} || $numtodo == 0) {
    ($xovercount, $numtodo) = (1, 1);
    my ($myxover) = grep /ROOT/, grep /^node/, keys %$mygenome;
    my ($matexover) = grep /ROOT/, grep /^node/, keys %$mategenome;
    die "problem with asexual 'crossover' - no ROOT nodes"
      unless ($myxover && $matexover);
    $myxpair{$myxover} = $matexover;
    $matexpair{$matexover} = $myxover;
    $asexual = 1;
  }

  while (keys %myseen < @mynodes &&
	 keys %mateseen < @matenodes &&
	 $xovercount < $numtodo) {
    # select one of my nodes
    my $mynode;
    do {
      $mynode = GPMisc::pickrandom(\@mynodes);
      $self->_tree_error($mynode, 'crossover')
	if (!defined $mysizes{$mynode});
    } until (rand($mymaxsize*$self->{XoverDepthBias}) <= $mysizes{$mynode});
    $myseen{$mynode} = 1;

    # select one of the mate's nodes
    my $matenode;

    # if a node with the same name exists in the mate,
    # use it (if QuickXoverProb is set accordingly)
    if (exists $matesizes{$mynode} &&
	$self->{QuickXoverProb} && rand() < $self->{QuickXoverProb}) {
      $matenode = $mynode;
    } else {
      # otherwise pick a random node as usual
      do {
	$matenode = GPMisc::pickrandom(\@matenodes);
	$mate->_tree_error($matenode, 'crossover2 nodes were '.join(':',@matenodes))
	  if (!defined $matesizes{$matenode});
      } until (rand($matemaxsize*$self->{XoverDepthBias}) <= $matesizes{$matenode});

      # do reverse quick homol check too
      if (exists $mysizes{$matenode} &&
	  $self->{QuickXoverProb} && rand() < $self->{QuickXoverProb}) {
	$mynode = $matenode;
	$myseen{$mynode} = 1;
      }
    }
    $mateseen{$matenode} = 1;

    if ($samples++>$maxsamples) {
      warn "xover too many tries ($xovercount out of $numtodo)\n";
      last;
    }
    # nodes have the same type structure and are not in subtrees of previously
    # picked xover nodes - or have been used before
    if ($mytypes{$mynode} eq $matetypes{$matenode} &&
	!exists $myxsubnodes{$mynode} && !exists $matexsubnodes{$matenode} &&
	!exists $myxpair{$mynode} && !exists $matexpair{$matenode}) {

      my $smaller = $mysizes{$mynode} < $matesizes{$matenode} ?
	$mysizes{$mynode} : $matesizes{$matenode};  # size of the smallest
      my $bigger = $mysizes{$mynode} > $matesizes{$matenode} ?
	$mysizes{$mynode} : $matesizes{$matenode};  # size of the biggest

      my $id;
      # if we accept the two subtrees as similar size:
      if (rand() > (abs($mysizes{$mynode} - $matesizes{$matenode})/$bigger)
	            ** (1/$self->{XoverSizeBias}) &&
	  # and content (crude homology):
	  rand() < ((($id = $self->_tree_id($mate, $mynode, $matenode)) + 0.1)
		    /$smaller)**$self->{XoverHomologyBias}) {

	my $pcid = int(100*$id/$smaller);

	# check to see if these nodes have other xover points in their subtrees
	my @myxsubnodes = $self->_get_subnodes($mynode);
	my @matexsubnodes = $mate->_get_subnodes($matenode);
	my $problem = 0;
	grep { $problem++ if (exists $myxpair{$_}); } @myxsubnodes;
	grep { $problem++ if (exists $matexpair{$_}); } @matexsubnodes;
	if ($problem == 0) {
	  # remember all the subnodes for the future
	  grep { $myxsubnodes{$_} = 1 } @myxsubnodes;
	  grep { $matexsubnodes{$_} = 1 } @matexsubnodes;

	  # and store the crossover point relationships
          $myxpair{$mynode} = $matenode;
	  $matexpair{$matenode} = $mynode;
	  $pcid{$mynode} = $pcid;
          $xovercount++;
	}
      }
    }
  }
  # now we actually do the cross over(s)
  if ($xovercount > 0) {

    # do some logging
    if ($self->XoverLogProb() &&
	rand() < $self->XoverLogProb() &&
	$self->XoverLogFile()) {
      if (open(FILE, ">>$self->{XoverLogFile}")) {
	if ($asexual) {
	  print FILE "doing 0 asexual\n";
	} else {
	  printf FILE "doing %d xovers\n", $xovercount;
	  foreach my $mynode (keys %myxpair) {
	    printf FILE "nodes %s %s sizes %d %d identity %d\n",
	      $mynode, $myxpair{$mynode},
		$mysizes{$mynode}, $matesizes{$myxpair{$mynode}},
		  $pcid{$mynode};
	  }
	}
	close(FILE);
      }
    }

    # do the crossovers
    $self->_start_crossover($mate, $recip1, \%myxpair);
    $mate->_start_crossover($self, $recip2, \%matexpair);
  }
  $self->untieGenome(); $mate->untieGenome();
}

sub _start_crossover {
  my ($self, $mate, $recipient, $selfxnode, $matexnode) = @_;
  my $rgenome = $recipient->tieGenome('crossrecip');
  %$rgenome = (); # wipe recipient's genome
  $recipient->retieGenome(); # actually wipe the DBM file
  $recipient->eraseMemory(); # erase the quick memory copies (fitness,age,...)
  $rgenome->{'tied'} = 1;
  $self->_crossover($mate, $recipient, 'root', '', $selfxnode);
  $recipient->_fix_nodes('root');
  $recipient->untieGenome();
}


# in _tree_id assume genomes are tied for speed
sub _tree_id {
  my ($self, $mate, $mynode, $matenode) = @_;
  if ($self->{genome}{$mynode} =~ /{node[A-Z]+\d+}/) {
    if ($mate->{genome}{$matenode} =~ /{node[A-Z]+\d+}/) {
      my $mycopy = $self->{genome}{$mynode};
      my $matecopy = $mate->{genome}{$matenode};
      $mycopy =~ s/{node([A-Z]+)\d+}/{$1}/g;
      $matecopy =~ s/{node([A-Z]+)\d+}/{$1}/g;
      if ($mycopy eq $matecopy) {
	my $sum = 1;
	my @mysubnodes = $self->{genome}{$mynode} =~ /{(node[A-Z]+\d+)}/g;
	my @matesubnodes = $mate->{genome}{$matenode} =~ /{(node[A-Z]+\d+)}/g;
	my $i;
	for ($i=0; $i<@mysubnodes; $i++) {
	  $sum += $self->_tree_id($mate, $mysubnodes[$i], $matesubnodes[$i]);
	}
	return $sum;
      }
      else {
	return 0;
      }
    }
    else {
      return 0;
    }
  }
  else { # they could both be terminal nodes
    return 1 if ($self->{genome}{$mynode} eq $mate->{genome}{$matenode});
  }
  return 0;
}

# assume genomes are tied for speed
sub _crossover {
  my ($self, $mate, $recip,
      $selfnode, $matenode, $myxpoint) = @_;
  my $newnode;

  if ($selfnode) {
    $newnode = ($recip->{genome}{$selfnode} = $self->{genome}{$selfnode});
  } else {
    $newnode = ($recip->{genome}{$matenode.'x'} = $mate->{genome}{$matenode});
  }

  my @subnodes = $newnode =~ /{(node[A-Z]+\d+)}/g;
  if ($matenode) {
    $recip->{genome}{$matenode.'x'} =~ s/{(node[A-Z]+\d+)}/{$1x}/g;
  }

  foreach $subnode (@subnodes) {
    my ($mynext, $matenext) = ($subnode, '');
    if ($selfnode && exists $myxpoint->{$subnode}) {
      ($mynext, $matenext) = ('', $myxpoint->{$subnode});
      $recip->{genome}{$selfnode} =~ s/{$subnode}/{$myxpoint->{$subnode}x}/;
    } elsif ($matenode) {
      ($mynext, $matenext) = ('', $subnode);
    }
    $self->_crossover($mate, $recip, $mynext, $matenext, $myxpoint);
  }
}

# assume genome is tied
sub _fix_nodes {
  my ($self, $node) = @_;

  my @subnodes = $self->{genome}{$node} =~ /{(node[A-Z]+\d+x?)}/g;
  foreach $subnode (@subnodes) {
    if ($subnode =~ /x$/) {
      my $fixed = $subnode;
      $fixed =~ s/x$//;
      $fixed =~ s/(\d+)$/$self->nid()/e while (defined $self->{genome}{$fixed});
      $self->{genome}{$node} =~ s/$subnode/${fixed}/;
      # ${fixed} is like this because emacs perl mode was playing up...!
      $self->{genome}{$fixed} = $self->{genome}{$subnode};
      delete $self->{genome}{$subnode};
      $subnode = $fixed;
    }
    $self->_fix_nodes($subnode);
  }

}

sub _random_node {
  my ($self, %p) = @_;

  my $depth_bias = $p{depth_bias} || 0;

  my %mysizes;
  my $start_node = $p{start_node} || 'root';
  $self->_tree_type_size($start_node, \%mysizes);
  my @mynodes = grep /^node(?!ROOT)/, keys %mysizes;
  my @temp = sort {$b <=> $a} values %mysizes;
  my $mymaxsize = shift @temp;

  my %subnodes;
  if ($p{not_this_subtree}) {
    grep { $subnodes{$_} = 1 } $self->_get_subnodes($p{not_this_subtree});
    $subnodes{$p{not_this_subtree}} = 1;
  }

  my ($randnode, $rtype);
  my $z = 0;
  # the depth_bias bit helps to give an even balance of subtree sizes
  do {
    $randnode = GPMisc::pickrandom(\@mynodes);
    ($rtype) = $randnode =~ /node([A-Z]+)\d+/;
    $self->_tree_error($randnode, 'mutate') if (!defined $mysizes{$randnode});
  } until (rand($mymaxsize*$depth_bias) <= $mysizes{$randnode} &&
	   (!defined $p{node_type} || $rtype eq $p{node_type}) &&
	   (!defined $p{not_this_node} || $randnode ne $p{not_this_node}) &&
	   (!defined $p{not_this_subtree} || !exists $subnodes{$randnode})
	   || ($z++ > $too_many_tries)
	  );

  return $z < $too_many_tries ? $randnode : '';
}


sub mutate {
  my ($self, %p) = @_;
  $self->reInitialise();
  my $genome = $self->tieGenome('mutate');

  my $i;
  $self->{mutednodes} = {};

  my $mutes_to_do = 0;
  unless ($self->FixedMutations()) {
    my $imax = keys %$genome;
    for ($i=0; $i<$imax; $i++) {
      $mutes_to_do++ if (rand() < $self->{NodeMutationProb});
    }
  } else {
    $mutes_to_do = $self->FixedMutations()
      if (rand() < $self->FixedMutationProb());

    my $imax = keys %$genome;
    for ($i=0; $i<$imax; $i++) {
      $i++ if (rand() < $self->{NodeMutationProb});
    }
  }

  for ($i=0; $i<$mutes_to_do; $i++) {
    my $unmutedcode = $self->{NoNeutralMutations} ? $self->_expand_tree() : '';

    if (rand() < $self->{PointMutationFrac}) {
      $self->point_mutate_shallow();
    } else {
      $self->macro_mutate();
    }

    # if necessary, check that the mutation actually changed the program
    if ($self->{NoNeutralMutations}) {
      my $mutedcode = $self->_expand_tree();
      if ($mutedcode eq $unmutedcode) {
	# allow another pass through mutation loop
	$mutes_to_do++ if ($mutes_to_do<$too_many_tries);
      }
    }
  }

  # reset fitness if we did any mutations
  if ($mutes_to_do) {
    $self->initFitness();
  }

  # do some logging
  if ($mutes_to_do && $self->MutationLogProb() &&
      rand() < $self->MutationLogProb() &&
      $self->MutationLogFile()) {
    if (open(FILE, ">>$self->{MutationLogFile}")) {
      printf FILE "did %d of %d\n",
	scalar(keys %{$self->{mutednodes}}), $mutes_to_do;
      foreach my $node (keys %{$self->{mutednodes}}) {
	my $size = 0;
	# node might not exist any more
	if (defined $genome->{$node}) {
	  $size = $self->_tree_type_size($node);
	}
	printf FILE "node $node size %d %s\n", $size,
	  $self->{mutednodes}{$node};
      }
      close(FILE);
    }
  }

  $self->untieGenome();
}

sub point_mutate_shallow {
  my $self = shift;
  $self->point_mutate($self->{PointMutationDepthBias});
}

sub point_mutate_deep {
  my $self = shift;
  $self->point_mutate($self->{MacroMutationDepthBias});
}

sub point_mutate {
  my ($self, $depth_bias) = @_;
  my $genome = $self->{genome};
  $depth_bias = $self->{PointMutationDepthBias}
    unless defined ($depth_bias);
  my $mutnode =
    $self->_random_node(depth_bias=>$depth_bias);
  return unless ($mutnode);

  my ($ntype) = $mutnode =~ /node([A-Z]+)\d+/;

  # if it's an internal node
  if ($genome->{$mutnode} =~ /{node[A-Z]+\d+}/) {
    my @subnodes = $genome->{$mutnode} =~ /{(node[A-Z]+\d+)}/g;
    my @subtypes = $genome->{$mutnode} =~ /{node([A-Z]+)\d+}/g;
    my $z = 0; my @newtypes;
    while ($z++<$too_many_tries) {
      my $newnode = $self->_random_function($ntype);
      @newtypes = $newnode =~ /{([A-Z]+)}/g;
      if ("@subtypes" eq "@newtypes") {
	$newnode =~ s/{[A-Z]+}/'{'.(shift @subnodes).'}'/ge;
	$genome->{$mutnode} = $newnode;
	$self->{mutednodes}{$mutnode} = 'point_internal';
	last;
      }
    }
  } else { # it's a terminal node
    # is it a number? (doesn't catch ".123")
    # and are we allowed to mutate them by multiplication?
    if (rand() < $self->{NumericMutationFrac} &&
	!$self->{NumericIgnoreNTypes}{$ntype} &&
	($self->{NumericAllowNTypes}{$ntype} ||
	 keys %{$self->{NumericAllowNTypes}} == 0) &&
	$genome->{$mutnode} =~ $self->{NumericMutationRegex}) {
      my $amount = $self->{NumericAllowNTypes}{$ntype} || 0.1;
      if (rand() < 0.5) {
	$genome->{$mutnode} *= 1+rand($amount); # small random change
      } else {
	$genome->{$mutnode} /= 1+rand($amount); # and the other way
      }
      # now keep it with a sensible number of significant figures
      $genome->{$mutnode} = sprintf "%.4g", $genome->{$mutnode};
      $self->{mutednodes}{$mutnode} = 'point_numeric';
    } else { # normal mutation by replacement
      $genome->{$mutnode} = $self->_random_terminal($ntype);
      $self->{mutednodes}{$mutnode} = 'point_terminal';
    }
  }
}

sub macro_mutate {
  my $self = shift;
  my $macro_type = GPMisc::pickrandom($self->{MacroMutationTypes});
  $self->$macro_type();
}

sub replace_subtree {
  my ($self) = @_;
  my $genome = $self->{genome};
  my $mutnode =
    $self->_random_node(depth_bias=>$self->{MacroMutationDepthBias});
  return unless ($mutnode);
  my ($ntype) = $mutnode =~ /node([A-Z]+)\d+/;

  # replace subtree with random subtree tree
  $self->_del_subtree($mutnode);
  my $newdepth = GPMisc::poisson($self->{NewSubtreeDepthMean},
				 $self->{NewSubtreeDepthMax});
  $genome->{$mutnode} = '';
  $genome->{$mutnode} =
    $self->_grow_tree(depth=>0, TreeDepthMax=>$newdepth, type=>$ntype);
  $self->{mutednodes}{$mutnode} = 'replace_subtree';
}

sub insert_internal {
  my ($self) = @_;
  my $genome = $self->{genome};
  my $mutnode =
    $self->_random_node(depth_bias=>$self->{MacroMutationDepthBias});
  return unless ($mutnode);
  my ($ntype) = $mutnode =~ /node([A-Z]+)\d+/;

  my $nodeid = $self->nid();
  $nodeid = $self->nid() while (defined $genome->{"node$ntype$nodeid"});
  my $newnode = "node$ntype$nodeid";
  my $copy = $genome->{$mutnode};
  my $insert;
  my $z = 0;
  do {
    $insert = $self->_random_function($ntype);
  } until ($z++>$too_many_tries || $insert =~ /{$ntype}/);
  if ($z<$too_many_tries) { # otherwise don't bother
    # copy mutnode to newnode so we can insert the new node at mutnode
    $genome->{$newnode} = $genome->{$mutnode};
    $genome->{$mutnode} = $insert;

    $self->{mutednodes}{$mutnode} = 'insert_internal';
    $self->{mutednodes}{$newnode} = 'insert_internal';

    my @posslinknodes = $genome->{$mutnode} =~ /{($ntype)}/g;
    my $linkupnode = int(rand(scalar @posslinknodes));
    $z = 0;
    while ($genome->{$mutnode} =~ /{([A-Z]+)}/) {
      my $subtype = $1;
      if ($subtype eq $ntype && $z++ == $linkupnode) { 
	# reconnect to original (copied) node
	$genome->{$mutnode} =~ s/{$ntype}/{$newnode}/;
      } else {
	# add new subtree of depth 0,1 or 2
	my $newdepth = GPMisc::poisson($self->{NewSubtreeDepthMean}, $self->{NewSubtreeDepthMax});
	$nodeid = $self->nid();
	$nodeid = $self->nid() while (defined $genome->{"node$subtype$nodeid"});
	my $subnode = "node$subtype$nodeid";
	$genome->{$mutnode} =~ s/{$subtype}/{$subnode}/;
	$genome->{$subnode} = '';
	$genome->{$subnode} =
	  $self->_grow_tree(depth=>0, TreeDepthMax=>$newdepth, type=>$subtype);
      }
    }
  }
}

sub delete_internal {
  my ($self) = @_;
  my $genome = $self->{genome};
  my $mutnode =
    $self->_random_node(depth_bias=>$self->{MacroMutationDepthBias});
  return unless ($mutnode);
  my ($ntype) = $mutnode =~ /node([A-Z]+)\d+/;

  my $secondnode =
    $self->_random_node(depth_bias=>$self->{MacroMutationDepthBias},
			start_node=>$mutnode,
			node_type=>$ntype,
			not_this_node=>$mutnode);
  if ($secondnode) {
    my @ripnodes = $genome->{$mutnode} =~ /{(node[A-Z]+\d+)}/g;
    $genome->{$mutnode} = $genome->{$secondnode};
    $self->_xcopy_subtree($mutnode);
    grep { $self->_del_subtree($_) } @ripnodes;
    grep { delete $genome->{$_} } @ripnodes;
    $self->_fix_nodes($mutnode);
    $self->{mutednodes}{$mutnode} = 'delete_internal';
    $self->{mutednodes}{$secondnode} = 'delete_internal';
  }
}

sub copy_subtree {
  my ($self) = @_;
  my $genome = $self->{genome};
  my $mutnode =
    $self->_random_node(depth_bias=>$self->{MacroMutationDepthBias});
  return unless ($mutnode);
  my ($ntype) = $mutnode =~ /node([A-Z]+)\d+/;

  # get another node that isn't in the subtree of mutnode
  my $secondnode =
    $self->_random_node(depth_bias=>$self->{MacroMutationDepthBias},
			node_type=>$ntype,
			not_this_subtree=>$mutnode);

  if ($secondnode) {
    # now check that mutnode isn't in the subtree of secondnode
    my %secondsubnodes;
    grep { $secondsubnodes{$_} = 1 } $self->_get_subnodes($secondnode);
    if (not exists $secondsubnodes{$mutnode}) {
      $self->_del_subtree($secondnode);
      $genome->{$secondnode} = $genome->{$mutnode};
      $self->_xcopy_subtree($secondnode);
      $self->_fix_nodes('root');
      $self->{mutednodes}{$mutnode} = 'copy_subtree';
      $self->{mutednodes}{$secondnode} = 'copy_subtree';
    }
  }
}

sub swap_subtrees {
  my ($self) = @_;
  my $genome = $self->{genome};
  my $mutnode =
    $self->_random_node(depth_bias=>$self->{MacroMutationDepthBias});
  return unless ($mutnode);
  my ($ntype) = $mutnode =~ /node([A-Z]+)\d+/;

  # get another node that isn't in the subtree of mutnode
  my $secondnode =
    $self->_random_node(depth_bias=>$self->{MacroMutationDepthBias},
			node_type=>$ntype,
			not_this_subtree=>$mutnode);

  if ($secondnode) {
    # now check that mutnode isn't in the subtree of secondnode
    my %secondsubnodes;
    grep { $secondsubnodes{$_} = 1 } $self->_get_subnodes($secondnode);
    if (not exists $secondsubnodes{$mutnode}) {
      # simply swap the contents of the two nodes and
      # everything will still be connected to something
      ($genome->{$mutnode}, $genome->{$secondnode}) =
	($genome->{$secondnode}, $genome->{$mutnode});

      $self->{mutednodes}{$mutnode} = 'swap_subtrees';
      $self->{mutednodes}{$secondnode} = 'swap_subtrees';
    }
  }
}

sub encapsulate_subtree {
  my ($self) = @_;
  my $genome = $self->{genome};
  my $genomesize = scalar keys %$genome;

  my $z = 0;
  while ($z++ < $too_many_tries) {
    my $mutnode =
      $self->_random_node(depth_bias=>$self->{MacroMutationDepthBias});
    return unless ($mutnode);
    my ($ntype) = $mutnode =~ /node([A-Z]+)\d+/;

    # some individuals don't allow certain subtrees to be frozen
    next if ($self->{EncapsulateIgnoreNTypes}{$ntype});

    my $subsize = $self->_tree_type_size($mutnode);
    # don't allow large fractions of the tree to be encapsulated
    next if ($subsize/$genomesize > $self->{EncapsulateFracMax});

    my $code = $self->_expand_tree($mutnode);
    $code = $self->simplify($code);

    # the length limit is a 'feature' of SDBM_File
    if (length($code) < 1000) {
      # replace subtree with the code that was the subtree
      $self->_del_subtree($mutnode);
      $genome->{$mutnode} = ";;$subsize;;$code";
      $self->{mutednodes}{$mutnode} = 'encapsulate_subtree';
      last; # we're done!
    }
  }
}

sub simplify {
  my ($self, $code) = @_;
  return $code;
}

# assume tied
sub _xcopy_subtree {
  my ($self, $node) = @_;
  my $genome = $self->{genome};

  my @subnodes = $genome->{$node} =~ /{(node[A-Z]+\d+)}/g;
  $genome->{$node} =~ s/{(node[A-Z]+\d+)}/{$1x}/g;
  foreach $subnode (@subnodes) {
    $genome->{$subnode.'x'} = $genome->{$subnode};
    $self->_xcopy_subtree($subnode.'x');
  }
}

# assume tied
sub _get_subnodes {
    my ($self, $node) = @_;
    my @subnodes = $self->{genome}{$node} =~ /{(node[A-Z]+\d+)}/g;
    my @retnodes = ();
    foreach $subnode (@subnodes) {
        push @retnodes, $self->_get_subnodes($subnode);
    }
    return (@subnodes, @retnodes);
}


# assume tied
sub _del_subtree {
  my ($self, $node) = @_;
  my $genome = $self->{genome};

  my @subnodes = $genome->{$node} =~ /{(node[A-Z]+\d+)}/g;
  if (@subnodes == 0) {
    delete $genome->{$node};
  }
  foreach $subnode (@subnodes) {
    $self->_del_subtree($subnode);
    delete $genome->{$subnode};
  }
}

# assume tied
sub _tree_type_size { 
  my ($self, $node, $sizes, $types, $ignore) = @_;
  my $genome = $self->{genome};

  my $nodetype = $node;
  $nodetype =~ s/node|\d+//g;

  $self->_tree_error($node, '_tree_type_size')
    if (!defined $genome->{$node});

  my @subnodes = $genome->{$node} =~ /{(node[A-Z]+\d+)}/g;
  if (@subnodes == 0) { # this is a leaf
    $sizes->{$node} = 1 if (defined $sizes);
    $types->{$node} = $nodetype if (defined $types);
    # is this an encapsulated subtree?  if so return the size of
    # the original - else 1
    return $genome->{$node}  =~ /^;;(\d+);;/ && $1 || 1;
  }
  # otherwise sum up the sizes of the subtrees
  # however if the $ignore hashref is defined then
  # don't recurse into subtree if the nodetype is in that hash
  my $sum = 1;
  unless (defined $ignore && $ignore->{$nodetype}) {
    foreach $subnode (@subnodes) {
      $sum += $self->_tree_type_size($subnode, $sizes, $types, $ignore);
    }
  }
  $sizes->{$node} = $sum if (defined $sizes);
  $types->{$node} = $nodetype if (defined $types);
  return $sum;
}

sub _display_tree {
  my ($self, $node) = @_;

  printf STDERR "%-12s = '%s'\n", $node, $self->{genome}{$node};
  my @subnodes = $self->{genome}{$node} =~ /{(node[A-Z]+\d+x?)}/g;
  grep $self->_display_tree($_), @subnodes;
}


sub saveCode {
  my ($self, %p) = @_;
  die unless ($p{Filename});

  if (open(FILE, ">$p{Filename}")) {
    my $fitness = defined $self->Fitness() ? $self->Fitness() : 'unevaluated';
    my $age = $self->Age();
    my $code = $self->getCode(); # get this first, in case there is no code
    my $size = $self->getSize();

    printf FILE "# Experiment: $self->{ExperimentId}\n";
    if (defined $p{Tournament}) {
      printf FILE "# Tournament: %d\n", $p{Tournament};
    }
    print FILE "# Fitness:  $fitness\n";
    print FILE "# Age:      $age\n";
    print FILE "# CodeSize: $size\n";
    print FILE "# Code follows:\n$code\n";
    close(FILE);
  }
}

sub save {
  my ($self, %p) = @_;
  die unless ($p{FileStem});

  my %copygenome = ();
  tie %copygenome, $DBTYPE, $p{FileStem}, O_RDWR | O_CREAT, 0644;
  my $genome = $self->tieGenome('save');
  foreach $key (keys %$genome) {
    $copygenome{$key} = $genome->{$key};
  }
  $self->untieGenome();
  $copygenome{'tied'} = 0;
  untie %copygenome;
}

sub load {
  my ($self, %p) = @_;
  die unless ($p{FileStem});

  my %copygenome;
  tie %copygenome, $DBTYPE, $p{FileStem}, O_RDONLY, 0644;
  my $genome = $self->tieGenome('load');
  %$genome = ();
  foreach $key (keys %copygenome) {
    $genome->{$key} = $copygenome{$key};
  }
  $self->untieGenome();
  untie %copygenome;
}

my %daVinci_colours = ('point_terminal'=>'red',
		       'point_numeric'=>'pink',
		       'point_internal'=>'yellow',
		       'insert_internal'=>'green',
		       'delete_internal'=>'brown',
		       'replace_subtree'=>'magenta',
		       'encapsulate_subtree'=>'orange',
		       'copy_subtree'=>'cyan',
		       'swap_subtrees'=>'#aaaaaa',
		       'crossover'=>'black',
		      );

# Saving a tree for the daVinci viewer:
# $blah->saveTree(Filename=>'foo.daVinci', StartNode=>'optional');
#
# if you want to highlight nodes, pass a hash like this
# $blah->saveTree(Highlight=>{nodeId=>'delete_internal'})
#
sub saveTree {
  my ($self, %p) = @_;
  die unless ($p{Filename});
  $p{StartNode} = 'root' unless ($p{StartNode});

  $self->tieGenome('saveTree');
  if (open(FILE, ">$p{Filename}")) {
    print FILE "[".$self->_daVincize($p{StartNode}, $p{HighLight})."]";
    close FILE;
  } else {
    warn "couldn't write to file $file - skipping at ", `date`;
  }
  $self->untieGenome();
}

sub _daVincize {
  my ($self, $node, $highlight) = @_;


  my ($nodetype) = $node =~ /node([A-Z]+)/;
  $nodetype = 'root' unless ($nodetype);

  my $nodetext = $self->{genome}{$node};
  my @subnodes = $nodetext =~ /{(node[A-Z]+\d+)}/g;
  $nodetext =~ s/__loop\w+__//g;
  $nodetext =~ s/{(node[A-Z]+\d+)}/_/g;
  $nodetext =~ s/\s+/ /g;
  $nodetext =~ s/"/'/g;

  $nodetext =~ s/^(.{1,80})\b.+$/$1.../ if (length($nodetext)>80);

  $nodetext = "$nodetype: $nodetext";

  my $edges = join ', ', map "l(\"$node.$_\", e(\"edge\", [], ".
                              $self->_daVincize($_, $highlight).
			      "))", @subnodes;

  my $hl = '';
  if ($highlight && $highlight->{$node}) {
    $hl = ",a(\"COLOR\",\"$daVinci_colours{$highlight->{$node}}\")";
  }

  # colour whole tree if no highlighting information is given:
  unless ($highlight) {
    # make an RGB colour from the first 6 hex digits of md5(nodetext);
    my $hexcol = substr(md5_hex($nodetext), 0, 6);
    $hl = ",a(\"COLOR\",\"#$hexcol\")";
  }


  return "l(\"$node\", n(\"node\", [a(\"OBJECT\", \"$nodetext\")$hl], [$edges]))";
}



1;
