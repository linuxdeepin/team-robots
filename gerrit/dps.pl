use Mojolicious::Lite;
use LWP::UserAgent;
use File::Basename;
use Scalar::Util qw(looks_like_number);

my $DPS_URL     = 'http://10.12:3000';
my $GERRIT_HOST = 'cr.deepin.io';
my $GERRIT_PORT = '29418';
my $GERRIT_USER = 'jenkins';

my $ua = new LWP::UserAgent;
my %changes;

sub getid {
  my $project = shift;

  my $path = dirname(__FILE__) . '/dps.ids';
  open(FILE, "<$path") or die 'dps.ids: file not found!';
  my @ids = <FILE>;
  my $line = (grep(/ $project/, @ids))[0];
  my $id = (split(' ', $line))[0];
  close(FILE);

  return $id;
}

sub build {
  my ($id, $branch) = @_;
  my $repo = '';

  $repo = 'hourly' if $branch eq 'develop';
  $repo = '2014'   if $branch =~ /release/;
  return 0 if not $repo;

  my $task = $ua->post("$DPS_URL/jenkis_api/add/$id", {
                 branch=>$branch,
                 repo=>$repo,
             })->decoded_content;

  return $task;
}

sub notify {
  my ($task, $message) = @_;
  my $change = $changes{$task};

  return 0 if not $change;

  my @cmd = ('ssh', "-p $GERRIT_PORT", "$GERRIT_USER\@$GERRIT_HOST", 'gerrit', 'review', "-m '$message'", "$change");
  system @cmd;
}

get '/dps' => sub {
  my $c = shift;
  my $project  = $c->param('project');
  my $changeid = $c->param('changeid');
  my $patchset = $c->param('patchset');
  my $branch   = $c->param('branch');

  my $task = build(getid($project), $branch);

  if (not looks_like_number($task)) {
    $c->render(status => 404, text => 'err');
    return;
  }

  $changes{$task} = "$changeid,$patchset";
  notify($task, "$DPS_URL/tasks/$task");

  $c->render(text => 'ok');
};

post '/dps/:task' => sub {
  my $c = shift;
  my $task    = $c->param('task');
  my $message = $c->param('message');

  notify($task, "DPS: $message");
  $c->render(text => "$message");
};

app->start;
