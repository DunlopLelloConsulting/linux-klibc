#!/usr/bin/perl
#
# Script to parse the SYSCALLS file and generate appropriate
# stubs.

($file, $arch, $bits, $unistd) = @ARGV;

require "arch/$arch/sysstub.ph";

if (!open(UNISTD, '<', $unistd)) {
    printf STDERR "$0: $unistd: $!\n";
    exit(1);
}
while ( defined($line = <UNISTD>) ) {
    chomp $line;

    if ( $line =~ /^\#\s*define\s+__NR_([A-Za-z0-9_]+)\s+(.*\S)\s*$/ ) {
	$syscalls{$1} = $2;
	print STDERR "SYSCALL FOUND: $1\n";
    }
}
close(UNISTD);

if (!open(HAVESYS, '>', "include/klibc/havesyscall.h")) {
    printf STDERR "$0: include/klibc/havesyscall.h: $!\n";
    exit(1);
}

print HAVESYS "#ifndef _KLIBC_HAVESYSCALL_H\n";
print HAVESYS "#define _KLIBC_HAVESYSCALL_H 1\n\n";

if (!open(FILE, '<', $file)) {
    print STDERR "$0: $file: $!\n";
    exit(1);
}

while ( defined($line = <FILE>) ) {
    chomp $line;
    $line =~ s/\s*(|[\#;].*)$//; # Strip comments and trailing blanks
    next unless $line;

    if ( $line =~ /^\s*(\<[^\>]+\>\s+|)([A-Za-z0-9_\*\s]+)\s+([A-Za-z0-9_,]+)(|\@[A-Za-z0-9_]+)(|\:\:[A-Za-z0-9_]+)\s*\(([^\:\)]*)\)\s*$/ ) {
	$archs  = $1;
	$type   = $2;
	$snames = $3;
	$stype  = $4;
	$fname  = $5;
	$argv   = $6;

	$doit  = 1;
	$maybe = 0;
	if ( $archs ne '' ) {
	    die "$file:$.: Invalid architecture spec: <$archs>\n"
		unless ( $archs =~ /^\<(|\?)(|\!)([^\>\!\?]*)\>/ );
	    $maybe = $1 ne '';
	    $not = $2 ne '';
	    $list = $3;

	    $doit = $not || ($list eq '');

	    @list = split(/,/, $list);
	    foreach  $a ( @list ) {
		if ( $a eq $arch || $a eq $bits ) {
		    $doit = !$not;
		    last;
		}
	    }
	}
	next if ( ! $doit );

	undef $sname;
	foreach $sn ( split(/,/, $snames) ) {
	    if ( defined $syscalls{$sn} ) {
		$sname = $sn;
		last;
	    }
	}
	if ( !defined($sname) ) {
	    next if ( $maybe );
	    die "$file:$.: Undefined system call: $snames\n";
	}

	$type  =~ s/\s*$//;
	$stype =~ s/^\@//;

	if ( $fname eq '' ) {
	    $fname = $sname;
	} else {
	    $fname =~ s/^\:\://;
	}

	@args = split(/\s*\,\s*/, $argv);

	print HAVESYS "#define _KLIBC_HAVE_SYSCALL_${fname} ${sname}\n";
	make_sysstub($fname, $type, $sname, $stype, @args);
    } else {
	print STDERR "$file:$.: Could not parse input: \"$line\"\n";
	exit(1);
    }
}

print HAVESYS "\n#endif\n";
close(HAVESYS);
