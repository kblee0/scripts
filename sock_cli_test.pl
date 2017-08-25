#!/usr/bin/perl
# Usage : sock_cli_test.pl [-x|-n] <ip> <port>
#        -x : binary send/recv test
#        -n : ascii send without "\r\n"
#
use IO::Socket;
use IO::Select;

$| = 1;

my ($send_x, $recv_x, $send_n) = (0,0,0);

if( $ARGV[0] eq '-x' ) {
	shift @ARGV;
	($send_x, $recv_x) = (1,1);
}
elsif( $ARGV[0] eq '-n' ) {
	shift @ARGV;
	$send_n = 1;
}

my ($ip, $port) = @ARGV;

$socket = new IO::Socket::INET (
    PeerAddr  => $ip,
    PeerPort  =>  $port,
    Proto     => 'tcp',
    Timeout   => 1
)
or die "Couldn't connect to Server($ip:$port). $!\n";

my $sel  = new IO::Select->new;
$sel->add($socket);
$sel->add(\*STDIN);

while ( 1 ) {
        my @ready = $sel->can_read(1);
        $i = 1;
        foreach my $fh (@ready) {
                if( $fh == $socket ) {
                        $len = sysread( $socket, $line, 4096 );
                        if( $len <= 0 ) {
                                $socket->close();
                                die "\nsocket closed($len).\n";
                        }
			if( $recv_x ) {
				print "RECV: $len\n";
				print_hex( $line );
			}
			else {
				printf "S[%04d]: $line", $len;
			}
                }
                elsif( $fh == \*STDIN ) {
                        my $line = <STDIN>;
                        chomp $line;
			my $bin = hex2bin( $line );
			if( $send_x ) {
				$len = syswrite( $socket, $bin, length( $line ) );
				print "SEND: $len\n";
				print_hex( $bin );
			}
			else {
				if( $send_n ) {
					$socket->send( "$line" );
				}
				else {
					$socket->send( "$line\r\n" );
				}
			}
                }
        }
}

$socket->close();

sub print_hex {
    my @a = unpack('C*',$_[0]);
    my $o = 0;
    while (@a) {
        my @b = splice @a,0,16;

        my @x = map sprintf("%02X",$_), @b;
        push @x, '  ' for ($#x..14);

        my $c = substr($_[0],$o,16);
        $c =~ s/[[:^print:]]/ /g;

        printf "%04xh: %s ; %s\n", $o, join(' ',@x), $c;

        $o += 16;
    }
}

sub hex2bin {
	my ($str) = @_;

	$str =~ s/\s//g;

	$ret = pack 'H*', $str;
}
