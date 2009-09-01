#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#
#
# Copyright (C) 2006-2009 Nexenta Systems, Inc.
# All rights reserved.
#

package nmc_bonnie_benchmark;

use Socket;
use NZA::Common;
use NMC::Const;
use NMC::Util;
use NMC::Term::Clui;
use strict;
use warnings;

##############################  variables  ####################################

my $benchmark_name = 'bonnie-benchmark';

my %benchmark_words =
(
	_enter => \&volume_benchmark,
	_usage => \&volume_benchmark_usage,
);

my $_benchmark_interrupted;


############################## Plugin Hooks ####################################

sub construct {
	my $all_builtin_word_trees = shift;

	my $setup_words = $all_builtin_word_trees->{setup};

	$setup_words->{$NMC::BENCHMARK}{$NMC::run_now}{$benchmark_name} = \%benchmark_words;
	$setup_words->{$NMC::VOLUME}{_unknown}{$NMC::BENCHMARK}{$NMC::run_now}{$benchmark_name} = \%benchmark_words;
}

############################## Setup Command ####################################

sub volume_benchmark_usage
{
	my ($cmdline, $prompt, @path) = @_;
	my ($numprocs, $quick, $block, $sync) = NMC::Util::get_optional('p:qb:s', \@path);
	print_out <<EOF;
$cmdline
Usage: [-p numprocs] [-b blocksize] [-q] [-s]

   -p <numprocs>     Number of process to run. Default is 2.
   -b <blocksize>    Block size to use. Default is 32k
   -s                No write buffering. fsync() after every write
   -q	             Quick mode. Warning: filesystem cache might
                     affect (and distort) results.

This benchmark is based on a popular Bonnie benchmark written originally 
by Tim Bray:

http://www.textuality.com/bonnie

Sequential Write (SEQ-WRITE):
    1. Block. The file is created using write(2). The CPU overhead 
       should be just the OS file space allocation.
    2. Rewrite. Each <blocksize> of the file is read with read(2), 
       dirtied, and rewritten with write(2), requiring an lseek(2). 
       Since no space allocation is done, and the I/O is well-localized,
       this should test the effectiveness of the filesystem cache and 
       the speed of data transfer.

Sequential Read (SEQ-READ):
    Block. The file is read using read(2). This should be a very pure
    test of sequential input performance.

Random Seeks (RND-SEEKS):
    This test runs SeekProcCount processes (default 3) in parallel, 
    doing a total of 8000 lseek()s to locations in the file specified 
    by random(). In each case, the block is read with read(2). 
    In 10% of cases, it is dirtied and written back with write(2).

Example:

  ${prompt}setup volume vol1 bonnie-benchmark -p 2 -b 8192
  Testing 'vol2'. Optimal mode. Using 1022MB files and 8192 blocks.
  Started 2 processes. This might take some time. Please wait...

  WRITE      CPU   REWRITE    CPU    READ      CPU    RND-SEEKS
  162MB/s    8%    150MB/s    6%     188MB/s   9%     430/sec
  158MB/s    7%    148MB/s    8%     184MB/s   7%     440/sec
  --------- ----   ---------  ----   --------- ----   ---------
  320MB/s    15%   298MB/s    13%    372MB/s   16%    870/sec 


See also: 'dtrace'
See also: 'show performance'

See also: 'show volume iostat'
See also: 'show volume <name> iostat'
See also: 'show lun iostat'

See also: 'show auto-sync <name> stats'
See also: 'show auto-tier <name> stats'

See also: 'run benchmark iperf-benchmark'

See also: 'help iostat'
See also: 'help dtrace'

EOF
}


sub _benchmark_get_data
{
	my ($filename, $h, $t) = @_;
	local *FD;

	if (! open(FD, $filename)) {
		print_error("Unable to open results: $!\n");
		return 0;
	}
	my @lines = <FD>;
	close FD;

	my $have_some = 0;
	for my $line (@lines) {
		my $name = $line;
	    	$name =~ s/,.*$//;
		$line =~ s/$name,//;
		my $ioline = $line;
		$ioline =~ s/,[:0-9\-\+.\/]+,[0-9\+.]+,[0-9\+.]+,[0-9\+.]+,[0-9\+.]+,[0-9\+.]+,[0-9\+.]+,[0-9\+.]+,[0-9\+.]+,[0-9\+.]+,[0-9\+.]+,[0-9\+.]+,[0-9\+.]+$//;
		$ioline =~ s/[\+]+//g;
		$ioline =~ s/,,,,,,,,,,,,,$//;
		my @data = split(/,/, $ioline);
		# ex: newisys-nas,2G:32k,,,28315,7,12988,1,,,109781,7,260.4,0
		$h->{seq_write_mbsec} = $data[4] / 1024 if ($data[4] && $data[4] =~ /[\d\.]+/);
		$h->{seq_write_cpu} = $data[5] if ($data[5] && $data[5] =~ /[\d\.]+/);
		$h->{seq_read_mbsec} = $data[6] / 1024 if ($data[6] && $data[6] =~ /[\d\.]+/);
		$h->{seq_read_cpu} = $data[7] if ($data[7] && $data[7] =~ /[\d\.]+/);
		$h->{rewrite_mbsec} = $data[10] / 1024 if ($data[10] && $data[10] =~ /[\d\.]+/);
		$h->{rewrite_cpu} = $data[11] if ($data[11] && $data[11] =~ /[\d\.]+/);
		$h->{seeks_sec} = $data[12] if ($data[12] && $data[12] =~ /[\d\.]+/);

		$t->{seq_write_mbsec} += $h->{seq_write_mbsec};
		$t->{seq_write_cpu} += $h->{seq_write_cpu};
		$t->{seq_read_mbsec} += $h->{seq_read_mbsec};
		$t->{seq_read_cpu} += $h->{seq_read_cpu};
		$t->{rewrite_mbsec} += $h->{rewrite_mbsec};
		$t->{rewrite_cpu} += $h->{rewrite_cpu};
		$t->{seeks_sec} += $h->{seeks_sec};
		$have_some++;
	}
	return $have_some;
}

sub _benchmark_fork {
	my ($cmd, $pidfile) = @_;

	if (defined (my $kid = fork)) {
		if ($kid) {
			waitpid($kid, 0);
		} else {
			if (defined (my $grandkid = fork)) {
				if ($grandkid) {
					system("echo $grandkid > $pidfile");
					CORE::exit(0);
				} else {
					system($cmd);
					CORE::exit(0);
				}
			} else {
				CORE::exit(0);
			}
		}
	}
}

sub _benchmark_begin
{
	my $scratch_dir = shift;
	my @lines = ();
	# NMS_CALLER as far as libzfs is concerned
	$ENV{$NZA::LIBZFS_ENV_NMS_CALLER} = 1;
	sysexec("zfs destroy $scratch_dir");
	if (sysexec("zfs create  $scratch_dir", \@lines) != 0) {
		print_error(@lines, "\n");
		return 0;
	}
	@lines = ();
	if (sysexec("chown admin $scratch_dir", \@lines) != 0) {
		print_error(@lines, "\n");
		return 0;
	}
	return 1;
}

sub _benchmark_end
{
	my $scratch_dir = shift;
	sysexec("zfs destroy $scratch_dir");
	delete $ENV{$NZA::LIBZFS_ENV_NMS_CALLER} if (exists $ENV{$NZA::LIBZFS_ENV_NMS_CALLER});
}

sub volume_benchmark
{
	my ($h, @path) = @_;
	my ($vol) = NMC::Util::names_to_values_from_path(\@path, $NMC::VOLUME);

	my ($numprocs, $quick, $block, $sync) = NMC::Util::get_optional('p:qb:s', \@path);
	$numprocs = 2 if (!defined $numprocs);

	$block = 32768 if (!defined $block);
	$block = NZA::Common::to_bytes($block);
	$block = 32768 if (!$block || $block !~ /^\d+$/);
	
	my $b_param = $sync ? '-b' : '';

	if (defined $vol && $vol eq $NZA::SYSPOOL) {
		print_error("Cannot use volume '$vol' for benchmarking: not supported yet\n");
		return 0;
	}

	my $volumes = &NZA::volume->get_names('');
	if (scalar @$volumes == 0) {
		print_error("No volumes in the system - cannot nothing to benchmark\n");
		return 0;
	}

	if (!defined $vol && scalar @$volumes == 1) {
		$vol = $volumes->[0];
		print_out("Volume '$vol' is the only available volume, starting benchmark...\n");
		sleep 1;
	}
	
	my $prompt = "Please select a volume to benchmark for performance";
	return 0 if (!NMC::Util::input_field("Select volume to run Bonnie++ file I/O benchmark",
					   0,
					   $prompt,
					   \$vol,
					   "on-empty" => $NMC::warn_no_changes,
					   cmdopt => 'v:',
					   'choose-from' => $volumes));

	return 0 if (NMC::Util::scrub_in_progress_bail_out($vol, 'cannot run I/O benchmark: '));

	my $size;
	my $s_param = '';
	eval {
		my $vmstat = &NZA::appliance->get_memstat();
		my $ram_total_mb = $vmstat->{ram_total};
		my $needed_mb = $ram_total_mb * 2;

		my $vol_avail = &NZA::volume->get_child_prop($vol, 'available');
		my $vol_avail_mb = NZA::Common::to_bytes($vol_avail);
		$vol_avail_mb = int($vol_avail_mb / 1024 / 1024);

		if ($quick) {
			if ($needed_mb > $vol_avail_mb && 0) {
				die "Volume '$vol' does not have enough free space to run '$benchmark_name'. Needed: approximately ${needed_mb}MB. Available: ${vol_avail_mb}MB.";
			}
			
			$size = int($ram_total_mb / 2);
			$s_param = "-r 0 -s $size:$block";
		}
		else {
			my $needed_mb_extra = $needed_mb * 4;
			if ($needed_mb_extra > $vol_avail_mb) {
				die "Volume '$vol' does not have enough free space to run '$benchmark_name'. Needed: approximately ${needed_mb_extra}MB. Available: ${vol_avail_mb}MB.";
			}

			$size = $needed_mb;
			$s_param = "-s $size:$block";
		}

	}; if (nms_catch($@)) {
		nms_print_error($@);
		return 0;
	}

	my $mode = $quick ? "quick" : "optimal";
	print_out("$vol: running $mode mode benchmark\n");
	print_out("$vol: generating ${size}MB files, using $block blocks\n");

	my %t = ();
	$t{seq_write_mbsec} = 0;
	$t{seq_write_cpu} = 0;
	$t{seq_read_mbsec} = 0;
	$t{seq_read_cpu} = 0;
	$t{rewrite_mbsec} = 0;
	$t{rewrite_cpu} = 0;
	$t{seeks_sec} = 0;

	my @lines = ();
	if (sysexec("bonnie -u admin -p${numprocs}", \@lines) != 0) {
		print_error(@lines, "\n");
		print_error("Use -h (help) option for information on available command line options\n");
		return 0;
	}

	my $scratch_dir = "$vol/.nmc-bonnie-benchmark";
	my $resfile = "/tmp/nmc-bonnie-benchmark.out.$$";

	# 
	# Set output autoflush on
	# 
	my $oldfh = select(STDOUT); my $fl = $|; $| = 1; select($oldfh);

	goto _exit_bmed unless (_benchmark_begin($scratch_dir));

	my %pids = ();
	for (my $i = 0; $i < $numprocs; $i++) {
		my $cmd = "bonnie -u admin $b_param $s_param -x 1 -y -n0 -f -d $scratch_dir > $resfile.$i 2>/dev/null";
		_benchmark_fork($cmd, "$resfile.pid.$i");
		sleep 1;
		if (-f "$resfile.pid.$i") {
			@lines = ();
			if (sysexec("cat $resfile.pid.$i", \@lines) == 0) {
				my $pid = $lines[0];
				$pids{$pid} = 1;
				unlink "$resfile.pid.$i";
			}
		}
	}

	print_out("$vol: started $numprocs benchmark processes\n");
	print_out("$vol: this may take a few minutes, please wait or press Ctrl-C to interrupt ");

	my $count = 1;
	$_benchmark_interrupted = 0;
	local $SIG{'INT'}   = sub { $_benchmark_interrupted = 1; };
	local $SIG{'KILL'}  = sub { $_benchmark_interrupted = 1; };
	while (scalar keys %pids) {
		for my $pid (keys %pids) {
			if (kill(0, $pid) == 0) {
				delete $pids{$pid};
			}
		}
		if ($_benchmark_interrupted) {
			print_out("Interrupted!\n");
			for my $pid (keys %pids) {
				kill(9, $pid);
			}
			last;
		}
		sleep 1;
		if (++$count % 5 == 0) {
			print_out(".");
		}
		if ($count % 60 == 0) {
			print_out("\n$vol: benchmark in progress, elapsed ${count} sec");
		}
	}

	goto _exit_bmed if ($_benchmark_interrupted);

	print_out("\n");

	# ignore error - try to count what we have...
	sysexec("bonnie -u admin -p-1 2>/dev/null");

	my $fmt = "%-9s %-4s   %-9s %-4s   %-9s %-4s   %-9s\n";
	my $hdr_printed = 0;
	my $numprocs_actual = 0;
	for (my $i = 0; $i < $numprocs; $i++) {
		if (-f "$resfile.$i") {
			my %h = ();
			$h{seq_write_mbsec} = 0;
			$h{seq_write_cpu} = 0;
			$h{seq_read_mbsec} = 0;
			$h{seq_read_cpu} = 0;
			$h{rewrite_mbsec} = 0;
			$h{rewrite_cpu} = 0;
			$h{seeks_sec} = 0;
			if (_benchmark_get_data("$resfile.$i", \%h, \%t) != 0) {
				if (! $hdr_printed) {
					hdr_printf($fmt, "WRITE", "CPU", "RE-WRITE", "CPU", "READ", "CPU", "RND-SEEKS");
					$hdr_printed = 1;
				}
				print_out(sprintf($fmt,
					int($h{seq_write_mbsec}) . "MB/s",
					int($h{seq_write_cpu}) . "%",
					int($h{seq_read_mbsec}) . "MB/s",
					int($h{seq_read_cpu}) . "%",
					int($h{rewrite_mbsec}) . "MB/s",
					int($h{rewrite_cpu}) . "%",
					int($h{seeks_sec}) . "/sec"));
				$numprocs_actual++;
			}
		}
	}

	if ($numprocs_actual != 0) {
		hdr_printf($fmt, "---------", "----", "---------", "----", "---------", "----", "---------", "----");
		$t{seeks_sec} = $t{seeks_sec} / $numprocs_actual;
		print_out(sprintf($fmt,
			int($t{seq_write_mbsec}) . "MB/s",
			int($t{seq_write_cpu}/$numprocs_actual) . "%",
			int($t{seq_read_mbsec}) . "MB/s",
			int($t{seq_read_cpu}/$numprocs_actual) . "%",
			int($t{rewrite_mbsec}) . "MB/s",
			int($t{rewrite_cpu}/$numprocs_actual) . "%",
			int($t{seeks_sec}) . "/sec"));
	} else {
		print_error("Not enough data to generate I/O performance report.\n");
		print_error("\nPlease make sure volume selected for benchmark has enough\n");
		print_error("free space; see help (-h) for more information.\n");
	}

_exit_bmed:
	if (! $fl) {
		$oldfh = select(STDOUT); $| = $fl; select($oldfh);
	}
	sysexec("bonnie -u admin -p-1");
	sysexec("rm -rf $resfile*");
	_benchmark_end($scratch_dir);
}

1;
