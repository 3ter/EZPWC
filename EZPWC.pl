#!/usr/env perl
# Eazy Perl Weekly Challenge EZPWC  
# This is a script that attempts to make Perl Weekly Challenges easier to do
# It creates a PerlChallenges directory in the home folder if not already
# present, forks the repo if needed, creates a clone, registers upstream,
# fetches the upstream and gets the most recent challenges.

#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#  
use strict;use warnings;
use LWP::Simple qw($ua get head);
use Cwd qw(getcwd);
use Scalar::Util qw(looks_like_number);


my $VERSION=0.02;

my $OS=$^O;
my %config;
my $workingDirectory="$ENV{HOME}/PerlChallenges";
print "Starting EZPWC \n";

loadConfig();

setupDirectory();        # step 1 set up a directory locally if it has not been setup
setupGithub();           # step 2 set up user's existing github account or setting up a new one
makeFork();              # step 3 set up fork if not already forked
clone();                 # step 4 clone if not already cloned
addUpstream();           # step 5 ensure upstream has been set up 
fetchUpstream();         # step 6 fetch upstream
getChallenges();         # step 7 get challenges from manwar's PWC blog
getBranches();           # step 8 get branches, and set one up for this week if required
readyToAdd();            # step 9 once ready to add
saveConfig();	
print "\n\nAll done...good bye!!";
exit 0;

sub setupDirectory{
	if ( -e $config{workingDirectory} and -d $config{workingDirectory}){
		print "Working directory found\n";
	}
	else{
		print "Attempting to create working directory $config{workingDirectory}...\n";
		mkdir $config{workingDirectory} 
			or die "Could not create working directory '$config{workingDirectory}' $!";
		chdir $config{workingDirectory};
		print "working directory created\n";
	}
}

sub setupGithub{
	if (($config{githubUN})&&(URLexists("https://github.com/$config{githubUN}"))){
		print "Github account for $config{githubUN} found...\n";
		return;		
	};
	
	print "Attempting to setup github...\n";

	while ($config{githubUN} eq ""){  # setup github, and fork the repo   
	   $config{githubUN} = prompt ("Enter your github username or S to skip or C to create one: \n"); 
	   if ($config{githubUN} =~/^s$/i){
		   $config{githubUN}="..Skipped";
		   print "Skipping... \n";
		   }
	   elsif ($config{githubUN} =~/^c$/i){
			print "Browser should open page to join Github and create an account\n";
			print "After signing up you can fork manwar's perlweeklychallenge-club\n";
			browse2("https://github.com/join?source_repo=manwar%2Fperlweeklychallenge-club");
			my $response=prompt ( "Click enter after signing up\n");
		    $config{githubUN} = "";
		}
	   elsif (URLexists("https://github.com/$config{githubUN}")){
		   print "Found your github\n";
	   }
	   else {
		   print "User '$config{githubUN}' not found on GitHub\n";
		   $config{githubUN} = "";
	   }
   }
   $config{githubUN}=undef if ($config{githubUN} eq "..Skipped");
}

sub makeFork{
	
    if (!$config{githubUN}) {print "GitHub account not setup so cannot fork\n";return};
    if ($config{"fork"})    {print "Fork already set up\n";return};
	
	print "Checking for fork $config{repoName};...\n";
	$config{"fork"}=undef;
    while (!$config{"fork"}){
		if (URLexists("https://github.com/".$config{githubUN}."/".$config{repoName})){
		      print "Found your fork https://github.com/".$config{githubUN}."/".$config{repoName}."\n";
		      $config{"fork"}="found";
	    }
	    else{
			my $response=prompt ( "Fork not found\nDo you wish to create a fork y/n?");
			if ($response=~/^y/i){
			   print "Browser should open the master repo after a login request\n";
			   print "click on 'Fork' to fork the repo\n";
			   browse2("https://github.com/login?return_to=%2F".$config{repoOwner}."%2F".$config{repoName});
			   my $response=prompt ( "\nPress enter once fork completed");
			}
			else{
			   print "Skipping creation of fork.  This will need to be completed later\n";
			   $config{"fork"}="skipped";
			}
		}
	}
	$config{"fork"}=undef if ($config{"fork"} eq "skipped");
}


sub clone{
	if (!$config{"fork"})   {print "Fork not setup so cannot clone\n";return}; 
	if ($config{"clone"})   {print "Clone found\n";return};
	
	print "cloning repo\n";
	if  ( -e "$config{workingDirectory}/$config{repoName}" and 
	                  -d "$config{workingDirectory}/$config{repoName}") {
		print "Clone already appears to exist\n";
		$config{clone}=1;
	}					  
	else {
		$config{clone}=0;
		chdir $config{workingDirectory};
		"Attempting to clone repo https://github.com/$config{githubUN}/$config{repoName}\n";	
		my $response= `git clone https://github.com/$config{githubUN}/$config{repoName}`;
		if ($response !~/^fatal/g){
			print "Success cloning repo";
			$config{clone}=1;
		};
	}
	
}

sub addUpstream{
	print "Checking out master\n";
	chdir "$config{workingDirectory}/$config{repoName}";
	`git checkout master`;
	if (upstreamExists()){
		print "Upstream already set up\n";
		$config{upstream}=1 ;
		return;
	}
	else{
		print "Attempting to add upstream\n";
		`git remote add upstream https://github.com/$config{repoOwner}/$config{repoName}`;
		if (upstreamExists()){
		 $config{upstream}=1 ;
		 print "Upstream added successfully" ; 
		}
		else{
		 $config{upstream}=0;
		 print "Upstream not added" ; 
		}
	}
}
	
sub fetchUpstream{
	if (!$config{"upstream"}){print "Upstream not setup so cannot Fetch Upstream\n";return}; 
	
	# Now we need to fetch latest changes from the upstream
	print "Fetching upstream\n";
	print `git fetch upstream`;
	
	# We will now merge the changes into your local master branch
	print `git merge upstream/master --ff-only`;   
	
	# Then push your master changes back to the repository.
	my $pushed=0;
	while (!$pushed ){
		my $response= `git push -u origin master`;
		if ($response !~/^fatal/g){
			$pushed=1
		}
		else{
			my $try=prompt ("Failed to fetch: Print any key to try again or 's' to skip");
			$pushed=1 if $try =~/s/i;
		}
	}
}

sub getChallenges{
	print "\n\nGetting challenges\n";
	my $week   = findItem("http://perlweeklychallenge.org",qr/perl-weekly-challenge-(\d+)/m);
	unless ((exists $config{currentweek})&&($config{currentweek} eq $week)){
		$config{currentBranch}=undef;
		$config{currentweek}=$week ;
	    $config{task1}  = findItem("http://perlweeklychallenge.org/blog/perl-weekly-challenge-$week",qr/TASK #1<\/h2>([\s\S]*)<h2 id="task-2">/m);
	    $config{task2}  = findItem("http://perlweeklychallenge.org/blog/perl-weekly-challenge-$week",qr/TASK #2<\/h2>([\s\S]*)<p>Last date /m);
    }

	print "\n\nCurrent week = $config{currentweek}\n";
	prompt ("Press any key");
	print "Task #1\n",$config{task1};
	prompt ("Press any key");
	print "\nTask #2\n", $config{task2};
	
}

sub getBranches{
	print "\n\nGetting branches ";
	my $br=`git ls-remote --heads`;
	my @matches = ($br =~ /refs\/heads\/(.+)\n/mg);
	print "\nBranches found : -",join ", ",@matches;
	if ($br=~/refs\/heads\/branch-$config{currentweek}\n/gm){
		print "\nBranch for current week ($config{currentweek}) found\n\n";
	}
	else{
		print "\nBranch for current week ($config{currentweek}) not found\nCreating branch-$config{currentweek}\n";
		print `git checkout -b branch-$config{currentweek}`;
	}
	print "Now add your responses to folder \n".
	      "$config{workingDirectory}/challenge-$config{currentweek}/$config{githubUN}/\n";
	prompt ("Press any key");  
	  }

sub readyToAdd{
	print "If you have added you responses to the folder and\n".
	      "you have tested them to your satisfaction, \n".
	      "you can now commit the answers - press 'y' if ready.\n".
	      "If you are not ready, just press 'n'...\n";
	my $response=prompt ("Are you ready to commit yor changes? (y/n)");
	if ($response =~/y/i){
		print "Adding current week's ($config{currentweek}) challenges...\n";
		print `git add challenge-$config{currentweek}/$config{githubUN}`;
		print `git commit`;
		print "Pushing results to your github...\n";
		print `git  push -u origin branch-$config{currentweek}`;
		print "Now time to create a pull request.  Browser should open\n".
		      "and you should see a button to create pull request...\n";
		browse2("https://github.com/login?return_to=%2F$config{githubUN}%2Fperlweeklychallenge-club");
	}
}


sub prompt{
	my ($message,$validation)=@_;
	print shift; print  " >>";
	chomp(my $response=<>);
	return $response; 
}

sub URLexists{
	my $url = shift;
	print "Checking if $url exists...\n";
	$ua->timeout(10);
	return head($url)? 1 : 0;
}

sub upstreamExists{
	return 1 if ($config{upstream});
	my $remote=`git remote -v`;
	return $remote =~/^upstream/m;
}

sub findItem{
	my ($url,$re)=@_;
	my $wp=get($url);
	if($wp=~/$re/){
		my $result=$1;
		$result=~s/<[^>]*>//gm;
		$result=~s/^\n+|\n+$/\n/gm;
		return $result;
		}
	else {return -1};
}


sub browse2{
	my ($URL)=(shift);
	print "Browser opening $URL, ($OS)";
	if     ($OS eq "linux")   {`xdg-open $URL`   }
	elsif  ($OS eq "MSWin32") {	`start /max $URL`}
	elsif  ($OS eq "darwin") {	`open "$URL"`}
}

sub saveConfig{
    open(my $fh, '>', $config{workingDirectory}.'/Config') or
         die "Could not open file '$config{workingDirectory}/Config' $!";
    for (sort keys %config){
		if (defined $config{$_}){
			print $fh " $_  => ".(looks_like_number($config{$_})?$config{$_}:"'$config{$_}'").",\n";
		}
		else{
			print $fh " $_  => undef,\n"
		}
	}
	close $fh;
}

sub loadConfig{
	if (-e "$workingDirectory/Config") {
		if (%config=do "$workingDirectory/Config" ){
			print "Config successfully loaded\n";
			return;
		}
		else {
		      print "Config exists but contains errors, please report.\n";
		}
	}

	print "Failed to load config, continuing with defaults\n";
	unlink ($config{workingDirectory}."/Config");
	%config=(
				repoName			 => "perlweeklychallenge-club",
				repoOwner			 => "manwar",
				workingDirectory     => "$ENV{HOME}/PerlChallenges",
				clone                => undef,
				githubUN			 => undef,
				"fork"				 => undef,
				upstream			 => undef,
			);
		
}
