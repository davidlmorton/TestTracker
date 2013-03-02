use strict;
use warnings;

use Cwd qw(cwd realpath);
use File::Basename qw(dirname);

my $lib_dir;
BEGIN {
    $lib_dir  = realpath(dirname(__FILE__) . '/../../lib');
}

use lib $lib_dir;

my $bin_dir  = realpath(dirname(__FILE__) . '/../../bin');
$ENV{PERL5LIB} = join(':', $lib_dir, $ENV{PERL5LIB});
$ENV{PATH} = join(':', $bin_dir, $ENV{PATH});

use File::Spec qw();
use Test::More;
use IPC::System::Simple qw(capture);
use Test::System import => [qw(run_ok)];
use Test::TestTracker import => [qw(
    db_filename
    conf_filename
    create_a_repo
    create_a_config
    create_a_database
)];
use TestTracker;
use File::Temp qw();

my $orig_cwd = cwd();

is($INC{'TestTracker.pm'}, File::Spec->join($lib_dir, 'TestTracker.pm'),
    "found correct TestTracker.pm");

my $tt_path = capture('which', 'test-tracker');
chomp $tt_path;
is($tt_path, File::Spec->join($bin_dir, 'test-tracker'),
    "found correct test-tracker bin");

my $git_dir = File::Temp->newdir(TMPDIR => 1);
chdir $git_dir;

create_a_repo($git_dir);

my $db_filename = db_filename();
my $conf_filename = conf_filename();

my %config = create_a_config();
run_ok(['git', 'add', $conf_filename]);
run_ok(['git', 'commit', '-m ""', $conf_filename]);

my %test_db = create_a_database();
run_ok(['git', 'add', $db_filename]);
run_ok(['git', 'commit', '-m ""', $db_filename]);

run_ok(['git', 'tag', '-a', '-m', '', 'start'], 'tagged repo as "start"');
run_ok(['git', 'reset', '--hard', 'start']);
run_ok(['git', 'clean', '-xdf']);

my @test_filenames = keys %test_db;
ok(@test_filenames > 0, 'test database has tracked tests');

my $tt_filename = $test_filenames[0];
run_ok(['touch', $tt_filename]);
my @found_ut_capture = capture('test-tracker', 'list', '--git');
my $found_ut = grep { $_ =~ /^\s+\d+\s+$tt_filename$/ } @found_ut_capture;
ok($found_ut, "found uncommitted, tracked test file: '$tt_filename'")
    or diag(join("\n", @found_ut_capture));

run_ok(['git', 'add', $tt_filename]);
run_ok(['git', 'commit', '-m ""', $tt_filename]);
run_ok(['git', 'clean', '-xdf']);
my @found_ct_capture = capture('test-tracker', 'list', '--git');
my $found_ct = grep { $_ =~ /^\s+\d+\s+$tt_filename$/ } @found_ct_capture;
ok($found_ct, "found committed, tracked test file: '$tt_filename'")
    or diag(join("\n", @found_ct_capture));

my $tu_filename = 'untracked.t';
ok((!grep { $_ eq $tu_filename } @test_filenames), 'verified untracked test file is not in test database');
run_ok(['touch', $tu_filename]);
my @found_uu_capture = capture('test-tracker', 'list', '--git');
my $found_uu = grep { $_ =~ /^\s+\d+\s+$tu_filename$/ } @found_uu_capture;
ok($found_uu, "found uncommitted, untracked test file: '$tu_filename'")
    or diag(join("\n", @found_uu_capture));

run_ok(['git', 'add', $tu_filename]);
run_ok(['git', 'commit', '-m ""', $tu_filename]);
run_ok(['git', 'clean', '-xdf']);
my @found_cu_capture = capture('test-tracker', 'list', '--git');
my $found_cu = grep { $_ =~ /^\s+\d+\s+$tu_filename$/ } @found_cu_capture;
ok($found_cu, "found committed, untracked test file: '$tu_filename'")
    or diag(join("\n", @found_cu_capture));

chdir $orig_cwd;
done_testing();