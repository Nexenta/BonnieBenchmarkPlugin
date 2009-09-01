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
# METAFILE FOR NMS

package Plugin::NmcBonnieBenchmark;
use base qw(NZA::Plugin);

$Plugin::CLASS				= 'NmcBonnieBenchmark';

$Plugin::NmcBonnieBenchmark::NAME		= 'nmc-bonnie-benchmark';
$Plugin::NmcBonnieBenchmark::DESCRIPTION	= 'Bonnie++ benchmark extension for NMC';
$Plugin::NmcBonnieBenchmark::LICENSE		= 'Open Source (CDDL)';
$Plugin::NmcBonnieBenchmark::AUTHOR		= 'Nexenta Systems, Inc';
$Plugin::NmcBonnieBenchmark::VERSION		= '1.3';
$Plugin::NmcBonnieBenchmark::GROUP		= '!bonnie-benchmark';
$Plugin::NmcBonnieBenchmark::LOADER		= 'Benchmark.pm';
@Plugin::NmcBonnieBenchmark::FILES		= ('Benchmark.pm');

1;
