#!/usr/bin/perl


## @file runner.pl
# @brief Centralnic test assignment


## @class Centralnic::Whois
#  @brief Centralnic test assignment
package Centralnic::Whois;
# *********************************************************************


=pod

=head1 NAME

runner.pl

=head1 DESCRIPTION

Get whois info for a domains list

=head1 SYNOPSIS

runner.pl [--in <path>] [--out <path>] [--limit <n>]  [--debug]

  Options:
    --help:        Print a summary of the command-line usage and exit.
    --in:          Path to a file with domain names list (one domain per line).
    --out:         Path to the file with result.
    --limit:       Exit when <n> domains from the list have passed.
    --debug:       Each request/response body are going to logging.

=head1 EXAMPLES

./runner.pl     \
  --in   /home/username/domains  \
  --out  /home/username/result   \
  --limit 1                      \
  --debug
=cut


use strict;
use warnings;
use utf8;

use FindBin;

BEGIN { 
	unshift @INC, "$FindBin::Bin/lib";
	# $ENV{HTTPS_DEBUG} = 0;  #Add debug output
}

use Pod::Usage;
use Encode qw(encode decode is_utf8);
use Encode;
use Data::Dumper;
use POSIX;
use Carp;
use Getopt::Long;
use Log::Log4perl;
use Time::HiRes;
use Data::Validate::Domain qw(is_domain);

use Interface::Whois;
use Util qw(debug trim tstamp println);


# $|=1;


GetOptions(
	'in=s'       => \( my $in           = undef),    # path to an input file with domains list
	'out=s'      => \( my $out          = undef),    # path to an output result file
	'domain=s'   => \( my $domain       = undef),    # domain name (for check how it works)
	'limit=i'    => \( my $limit        = undef),    # limit on the number of requests during testing
	'debug'      => \( my $debug        = undef),    # log whois response
	"help|h"     => \( my $help         = undef),    # help
);



if ($help) {
	pod2usage( -exitstatus => 0, -verbose => 99, -sections => [ qw|NAME DESCRIPTION SYNOPSIS| ] );
}

unless ( defined $in || defined $domain ) {
	println('Error: one of the "in" or "domain" param is required');
	exit;
}


main(
	in     => $in,
	domain => $domain,
	out    => $out,
	limit  => $limit,
	debug  => $debug,
);


sub main {
	my %p = @_;

	Log::Log4perl->init( {
		'log4perl.rootLogger'                   => 'INFO, LOGFILE',
		'log4perl.appender.LOGFILE'             => 'Log::Log4perl::Appender::File',
		'log4perl.appender.LOGFILE.filename'    =>  Util::abs_path('log/whois.log'),
		'log4perl.appender.LOGFILE.mode'        => 'append',
		'log4perl.appender.LOGFILE.layout'      => 'PatternLayout',
		'log4perl.appender.LOGFILE.layout.ConversionPattern' => '%d{yyyy-MM-dd HH:mm:ss} pid:%P %p %m%n',
		# 'log4perl.appender.LOGFILE.layout.ConversionPattern' => '%d{yyyy-MM-dd hh:mm:ss SSSSS} %P %p %m%n',
		# explain the format: yyyy-mm-dd hh:mm:ss millisecond pid level message new_line
	});

	my $logger = Log::Log4perl->get_logger();

	$logger->info('Debug flag is ON, all whois response string will be saved at the debug.log file.')
		if $p{debug};

	my $whois = Interface::Whois->new(
		logger => $logger,
		debug  => $p{debug},
	);

	my $path = Util::abs_path($p{in});
	unless (-e $path) { return croak ("Input file '$path' not found.") };

	open(F, '<', $path) 
		or croak('Can not open file : '.$path.'. '.$!);

	my $c = 0;

	println('domain;status');

	while (my $line = <F>) {

		$c++;

		my $domain = Util::trim($line);
		next unless $domain;
		next if $domain =~ /^#/;

		unless (is_domain($domain)) {
			$logger->warn('Warning: the string "'.$domain.'" at the line '.$c.' doesn\'t look like a domain name. Go to the next line.');
			next;
		}

		$logger->info('Get whois info for the domain "'.$domain .'"');

		my $res = $whois->get_info($domain);

		unless ($res) {
			println($domain.';ERROR: UNKNOWN_WHOIS');
			$logger->error('Unknown whois server, go to the next line.');
			next;
		}

		$logger->info('Whois server: '.$res->srv);

		# process errors
		unless ( $res->is_success) {

			$logger->error($domain.';ERROR: '.$res->error_code);
			println($domain.';ERROR: '.$res->error_code);

			$logger->error( 
				$res->error_code eq 'NOT_FOUND'
					? 'Domain '.$res->domain.' not found at the whois server "'.$res->srv.'"'
					: $res->error_code eq 'TIMEOUT'
						? 'Request timeout for the whois server "'.$res->srv.'"'
						: $res->error_code eq 'UNKNOWN_RESPONSE_FORMAT'
							? 'Unknown whois "'.$res->srv.'" response format for the domain "'.$res->domain.'", see the debug.log file'
							: 'Unknown whois "'.$res->srv.'" error'
			);

			next;
		}

		# task 1: print domain and domain statuses
		# println( join ';', $domain, join(',', $res->domain_status) );

		# task 2: append expire domain date
		my $expire_part =  $res->domain_expire_date
			? Util::format_date( $res->domain_expire_date, 'YYYY-MM-DD hh:mm:ss', 'GMT' ) .';'.$res->domain_expire_days
			: '-;-';

		println( join ';', $domain, join(',', $res->domain_status), $expire_part );

		$logger->info('Success getting whois info');
	}

	close F;

}

1;

__END__

