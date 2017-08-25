#!/usr/bin/perl
use strict;

use Socket;
use IO::Socket::INET;
use Getopt::Std;
use POSIX qw(strftime);

my ($socket,$client_socket);
my ($peeraddress,$peerport);

my %opts = ();
getopts( "p:v:", \%opts );

if( not defined $opts{p} ) {
	die "Usage : sock_accept_test.pl -p <Server port no> [-v IP1:IP2:...]\n";
}

my $port = int($opts{p});

my %skip_log_ip = ();
if( defined $opts{v} ) {
	for my $vip ( split( /:/, $opts{v} ) ) {
		$skip_log_ip{$vip} = 1;
	}
}

$| = 1;

$socket = new IO::Socket::INET (
	LocalHost => "0.0.0.0",
	LocalPort => $port,
	Proto => "tcp",
	Listen => 5,
	Reuse => 1
	) or die "ERROR in Socket Creation : $!\n";
	
&log_print( "SERVER Waiting for client connection on port $port" );



while(1)
{
	# waiting for new client connection.
	$client_socket = $socket->accept();
	
	# get the host and port number of newly connected client.
	my $peer_address = $client_socket->peerhost();
	my $peer_port = $client_socket->peerport();
	
	if( not defined $skip_log_ip{$peer_address} ) {
		&log_print( "Accepted New Client Connection $peer_address:$peer_port" );
	}
	
	$client_socket->close();
}

$socket->close();

sub log_print {
	print '[' . strftime( '%Y/%m/%d %H:%M:%S', localtime ) . '] ', @_, "\n";
}

