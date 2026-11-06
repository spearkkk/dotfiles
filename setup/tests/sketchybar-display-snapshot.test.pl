#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use JSON::PP qw(encode_json decode_json);
use FindBin;

my $base = shift // "$FindBin::Bin/../..";
my $helper = "$base/home/.local/libexec/sketchybar-display-snapshot";
my $loaded = do $helper;
ok($loaded, 'snapshot package loads without running screen queries')
    or diag($@ || $!);
unless ($loaded) { done_testing(); exit 1; }

sub clone { decode_json(encode_json($_[0])) }
sub fixtures {
    my $native = [
        {direct_display_id => 31, name => 'Allowed'},
        {direct_display_id => 72, name => 'Blocked'},
    ];
    my $bar = [
        {DirectDisplayID => 72, 'arrangement-id' => 1, UUID => 'uuid-b',
         frame => {x => -1920, y => 0, w => 1920, h => 1080}},
        {DirectDisplayID => 31, 'arrangement-id' => 2, UUID => 'uuid-a',
         frame => {x => 0, y => -0.5, w => 2560, h => 1440}},
    ];
    return ($native, $bar, clone($native), clone($bar));
}
sub unresolved {
    my ($name, $change) = @_;
    my @reads = fixtures();
    $change->(\@reads);
    is_deeply(DisplaySnapshot::normalize(@reads),
        {status => 'error', reason => 'identity_unresolved'}, $name);
}

my @reads = fixtures();
my $original = clone(\@reads);
my $snapshot = DisplaySnapshot::normalize(@reads);
is($snapshot->{status}, 'ready', 'complete stable mapping is ready');
is_deeply($snapshot->{displays}, [
    {identity => 'uuid-b', name => 'Blocked', sketchybar_id => 1},
    {identity => 'uuid-a', name => 'Allowed', sketchybar_id => 2},
], 'join native IDs, not array positions; return all displays in arrangement order');
is_deeply(\@reads, $original, 'normalization does not mutate its inputs');
my $key = '[{"direct_display_id":72,"frame":{"h":1080,"w":1920,"x":-1920,"y":0},"identity":"uuid-b","name":"Blocked","sketchybar_id":1},{"direct_display_id":31,"frame":{"h":1440,"w":2560,"x":0,"y":-0.5},"identity":"uuid-a","name":"Allowed","sketchybar_id":2}]';
is($snapshot->{topology_key}, $key, 'canonical topology includes every ID, UUID, name and frame');

@reads = fixtures();
@{$reads[2]} = reverse @{$reads[2]};
@{$reads[3]} = reverse @{$reads[3]};
$reads[0][0]{focused} = 1;
$reads[2][0]{focused} = 0;
$reads[1][0]{focused} = JSON::PP::true;
$reads[3][0]{focused} = JSON::PP::false;
is_deeply(DisplaySnapshot::normalize(@reads), $snapshot,
    'array ordering and unrelated focus fields do not affect topology');

@reads = fixtures();
for my $index (1, 3) {
    $reads[$index][0]{'arrangement-id'} = 2;
    $reads[$index][1]{'arrangement-id'} = 1;
}
my $swapped = DisplaySnapshot::normalize(@reads);
is_deeply($swapped->{displays}, [
    {identity => 'uuid-a', name => 'Allowed', sketchybar_id => 1},
    {identity => 'uuid-b', name => 'Blocked', sketchybar_id => 2},
], 'reconnection remaps current arrangement IDs without reusing old IDs');
isnt($swapped->{topology_key}, $snapshot->{topology_key}, 'arrangement changes change topology');

for my $case (
    ['frame', sub { $_[0][1][0]{frame}{x} = -2000; $_[0][3][0]{frame}{x} = -2000 }],
    ['name', sub { $_[0][0][0]{name} = 'Renamed'; $_[0][2][0]{name} = 'Renamed' }],
    ['UUID', sub { $_[0][1][0]{UUID} = 'replacement'; $_[0][3][0]{UUID} = 'replacement' }],
) {
    @reads = fixtures();
    $case->[1]->(\@reads);
    my $changed = DisplaySnapshot::normalize(@reads);
    is($changed->{status}, 'ready', "stable changed $case->[0] is ready");
    isnt($changed->{topology_key}, $key, "$case->[0] change alters topology");
}
is_deeply(DisplaySnapshot::normalize([], [], [], []),
    {status => 'ready', topology_key => '[]', displays => []}, 'empty screen sets are ready');

@reads = fixtures();
$reads[0][1]{name} = $reads[2][1]{name} = 'Allowed';
is(scalar @{DisplaySnapshot::normalize(@reads)->{displays}}, 2,
    'identical monitor names retain both identities');

for my $index (0 .. 3) {
    unresolved("missing entry in read $index rejects whole snapshot", sub { pop @{$_[0][$index]} });
    unresolved("duplicate entry in read $index rejects whole snapshot", sub {
        push @{$_[0][$index]}, clone($_[0][$index][0]);
    });
    for my $bad (undef, {}, 'not an array', [undef], [[]]) {
        unresolved("invalid read/entry shape in read $index", sub { $_[0][$index] = $bad });
    }
}
for my $index (0, 2) {
    for my $bad (undef, '', 7, [], {}, JSON::PP::true) {
        unresolved("invalid native name in read $index", sub { $_[0][$index][0]{name} = $bad });
    }
    unresolved("native name changes during read $index", sub { $_[0][$index][0]{name} = 'Changed' });
}
for my $index (1, 3) {
    for my $bad (undef, '', 7, [], {}, JSON::PP::true) {
        unresolved("invalid UUID in read $index", sub { $_[0][$index][0]{UUID} = $bad });
    }
    unresolved("UUID changes during read $index", sub { $_[0][$index][0]{UUID} = 'Changed' });
    unresolved("duplicate arrangement ID in read $index", sub {
        $_[0][$index][0]{'arrangement-id'} = $_[0][$index][1]{'arrangement-id'};
    });
    unresolved("duplicate UUID in read $index", sub { $_[0][$index][0]{UUID} = $_[0][$index][1]{UUID} });
    unresolved("arrangement changes during read $index", sub { $_[0][$index][0]{'arrangement-id'} = 3 });
    for my $bad (undef, [], {}, {x => 0, y => 0, width => 100, height => 100}) {
        unresolved("invalid live frame shape in read $index", sub { $_[0][$index][0]{frame} = $bad });
    }
    for my $field (qw(x y w h)) {
        for my $bad (undef, '0', 'NaN', 'Inf', [], {}, JSON::PP::true) {
            unresolved("invalid frame $field in read $index", sub { $_[0][$index][0]{frame}{$field} = $bad });
        }
        unresolved("frame $field changes during read $index", sub { $_[0][$index][0]{frame}{$field} += 1 });
    }
    for my $field (qw(w h)) {
        for my $bad (0, -1) {
            unresolved("nonpositive frame $field in read $index", sub { $_[0][$index][0]{frame}{$field} = $bad });
        }
    }
}
for my $index (0 .. 3) {
    my @fields = $index % 2 ? ('DirectDisplayID', 'arrangement-id') : ('direct_display_id');
    for my $field (@fields) {
        for my $bad (undef, 0, -1, 1.5, '1', 'bad', [], {}, JSON::PP::true) {
            unresolved("invalid $field in read $index", sub { $_[0][$index][0]{$field} = $bad });
        }
    }
}
unresolved('stable but different native/bar ID sets cannot produce partial results', sub {
    $_[0][0][0]{direct_display_id} = $_[0][2][0]{direct_display_id} = 99;
});

subtest 'stable malformed data fails validation, not just before/after comparison' => sub {
    for my $bad (0, -1, 1.5, '31') {
        my ($native, $bar) = fixtures();
        $native->[0]{direct_display_id} = $bar->[1]{DirectDisplayID} = $bad;
        is_deeply(DisplaySnapshot::normalize($native, $bar, clone($native), clone($bar)),
            {status => 'error', reason => 'identity_unresolved'},
            'matching but invalid direct IDs are rejected');
    }
    for my $case (
        ['empty name', sub { $_[0][0]{name} = '' }],
        ['numeric name', sub { $_[0][0]{name} = 42 }],
        ['empty UUID', sub { $_[1][0]{UUID} = '' }],
        ['numeric UUID', sub { $_[1][0]{UUID} = 42 }],
        ['duplicate UUID', sub { $_[1][0]{UUID} = $_[1][1]{UUID} }],
        ['duplicate native ID', sub { push @{$_[0]}, clone($_[0][0]) }],
        ['duplicate bar ID', sub { push @{$_[1]}, clone($_[1][0]) }],
        ['duplicate arrangement', sub { $_[1][0]{'arrangement-id'} = 2 }],
        ['zero arrangement', sub { $_[1][0]{'arrangement-id'} = 0 }],
        ['fractional arrangement', sub { $_[1][0]{'arrangement-id'} = 1.5 }],
        ['missing frame coordinate', sub { delete $_[1][0]{frame}{x} }],
        ['string frame coordinate', sub { $_[1][0]{frame}{x} = '0' }],
        ['empty frame', sub { $_[1][0]{frame} = {} }],
        ['zero frame width', sub { $_[1][0]{frame}{w} = 0 }],
        ['negative frame height', sub { $_[1][0]{frame}{h} = -1 }],
    ) {
        my ($native, $bar) = fixtures();
        $case->[1]->($native, $bar);
        is_deeply(DisplaySnapshot::normalize($native, $bar, clone($native), clone($bar)),
            {status => 'error', reason => 'identity_unresolved'}, "$case->[0] fails closed");
    }
};

subtest 'collection emits one snapshot after native/bar/native/bar argv queries' => sub {
    unless (ok(DisplaySnapshot->can('main'), 'collection entry point exists')) { return }
    my @responses = fixtures();
    my @commands;
    my $output = '';
    {
        no warnings 'redefine';
        local *DisplaySnapshot::_sketchybar_path = sub { '/opt/homebrew/bin/sketchybar' };
        local *DisplaySnapshot::_query_json = sub {
            push @commands, [@_];
            return shift @responses;
        };
        open my $out, '>', \$output or die $!;
        local *STDOUT = $out;
        DisplaySnapshot::main();
    }
    is_deeply(decode_json($output), $snapshot, 'main emits normalized JSON, not raw query output');
    is(scalar @commands, 4, 'exactly four sequential reads');
    is_deeply([@{$commands[0]}[0 .. 2]], ['/usr/bin/osascript', '-l', 'JavaScript'],
        'native read uses JXA argv');
    is($commands[0][3], '-e', 'AppKit script is a single argv argument');
    is(scalar @{$commands[0]}, 5, 'no shell wrapper around JXA');
    is_deeply($commands[1], ['/opt/homebrew/bin/sketchybar', '--query', 'displays'],
        'second read is SketchyBar displays argv');
    is_deeply($commands[2], $commands[0], 'third read repeats native collection');
    is_deeply($commands[3], $commands[1], 'fourth read repeats SketchyBar collection');
};

subtest 'collection failures never expose partial screen lists' => sub {
    unless (ok(DisplaySnapshot->can('main'), 'collection entry point exists')) { return }
    for my $failed_read (0 .. 3) {
        my @responses = fixtures();
        $responses[$failed_read] = undef;
        my $output = '';
        {
            no warnings 'redefine';
            local *DisplaySnapshot::_sketchybar_path = sub { '/usr/local/bin/sketchybar' };
            local *DisplaySnapshot::_query_json = sub { shift @responses };
            open my $out, '>', \$output or die $!;
            local *STDOUT = $out;
            DisplaySnapshot::main();
        }
        is_deeply(decode_json($output), {status => 'error', reason => 'query_failed'},
            "query failure at read $failed_read fails closed");
    }
    my $output = '';
    {
        no warnings 'redefine';
        local *DisplaySnapshot::_sketchybar_path = sub { undef };
        local *DisplaySnapshot::_query_json = sub { die 'must not query without a binary' };
        open my $out, '>', \$output or die $!;
        local *STDOUT = $out;
        DisplaySnapshot::main();
    }
    is_deeply(decode_json($output), {status => 'error', reason => 'query_failed'},
        'missing SketchyBar binary fails closed');
};

subtest 'query execution validates exit and JSON without a shell' => sub {
    unless (ok(DisplaySnapshot->can('_query_json'), 'argv query boundary exists')) { return }
    my $literal = 'space ; $(exit 91) "quoted" *';
    is_deeply(DisplaySnapshot::_query_json('/usr/bin/perl', '-MJSON::PP', '-e',
        'print encode_json(\@ARGV)', '--', $literal), [$literal],
        'shell metacharacters remain literal argv');
    is_deeply(DisplaySnapshot::_query_json('/usr/bin/perl', '-e', 'print "[]"'), [],
        'empty JSON array is a successful query');
    for my $case (
        ['nonzero exit with valid JSON', 'print "[]"; exit 2'],
        ['signal exit', 'kill 15, $$'],
        ['malformed JSON', 'print "["'],
        ['empty stdout', 'exit 0'],
        ['object instead of screen list', 'print "{}"'],
        ['null instead of screen list', 'print "null"'],
        ['scalar instead of screen list', 'print "1"'],
        ['multiple JSON documents', 'print "[] []"'],
    ) {
        is(DisplaySnapshot::_query_json('/usr/bin/perl', '-e', $case->[1]), undef,
            "$case->[0] is a query failure");
    }
    is(DisplaySnapshot::_query_json('/nonexistent/sketchybar-fixture', '--query', 'displays'),
        undef, 'spawn failure is a query failure');
};

done_testing();
