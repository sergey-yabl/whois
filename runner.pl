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
	$ENV{HTTPS_DEBUG} = 0;  #Add debug output
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
#use LoadEpp;
#use Stat;

# $|=1;


GetOptions(
	'in=s'       => \( my $in           = undef),    # path to an input file with domains list
	'out=s'      => \( my $out          = undef),    # path to an output result file
	'domain=s'   => \( my $domain       = undef),    # domain name (for check how it works)
	'limit=i'    => \( my $limit        = undef),    # limit on the number of requests during testing
	'debug'      => \( my $debug        = undef),    # log the content of all EPP requests/responses
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

	my $thread_num = shift;
	my $stat  = shift;
	my $prob_scale  = shift;
	my $debug = shift;

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

	my $whois = Interface::Whois->new(
		logger => $logger,
		debug  => $debug,
	);

	my $path = Util::abs_path($in);
	unless (-e $path) { return croak ("Input file '$path' not found.") };

	open(F, '<', $path) 
		or croak('Can not open file : '.$path.'. '.$!);

	my $c = 0;

	while (my $line = <F>) {

		$c++;

		my $domain = Util::trim($line);
		next unless $domain;
		next if $domain =~ /^#/;

		println $domain;

		unless (is_domain($domain)) {
			warn('Warning: the string "'.$domain.'" at the line '.$c.' doesn\'t look like a domain name. Go to the next line.');
			next;
		}

		# $Net::Whois::Raw::TIMEOUT = 10;
		#my $dominfo = whois($domain, 'whois.nic.info');
		#my $dominfo = whois('info', 'whois.iana.org');
		# my $dominfo = whois('key-systems.info', 'whois.nic.info');
		#my $dominfo = get_whois($domain, 'whois.iana.org');
		
		my $res = $whois->get_info('key-systems.info');


		println($res->raw);
	}

	close F;

}


__END__



sub main {

	my $thread_num = shift;
	my $stat  = shift;
	my $prob_scale  = shift;
	my $debug = shift;

	Log::Log4perl->init( {
		'log4perl.rootLogger'                   => 'INFO, LOGFILE',
		'log4perl.appender.LOGFILE'             => 'Log::Log4perl::Appender::File',
		'log4perl.appender.LOGFILE.filename'    =>  Util::abs_path('log/loader.log'),
		'log4perl.appender.LOGFILE.mode'        => 'append',
		'log4perl.appender.LOGFILE.layout'      => 'PatternLayout',
		'log4perl.appender.LOGFILE.layout.ConversionPattern' => '%d{yyyy-MM-dd HH:mm:ss} pid:%P %p %m%n',
		# 'log4perl.appender.LOGFILE.layout.ConversionPattern' => '%d{yyyy-MM-dd hh:mm:ss SSSSS} %P %p %m%n',
		# explain format: yyyy-mm-dd hh:mm:ss millisecond pid level message new_line
	});

	my $logger = Log::Log4perl->get_logger();

	my $config = Util::read_yaml($config_path || 'conf/load.conf')
		or die('ERROR: Can not read config file: ' . $!);

	my $epp = LoadEpp->new(
		logger      => $logger,
		config      => $config,
		debug       => $debug,
	);

	my $sid = $epp->connect;

	die 'ERROR: Can not connect to the EPP interface, see logs for details, rid: '.$epp->last_rid
		unless $sid;

	println('Thread '.$thread_num.': connect and loggin are success; host: '.$config->{address});

	while(1){
		# print $c;

		# reached the request or time limit
		if ( 
			( defined $limit_number && $c >= int $limit_number )
			||
			( defined $limit_time && int $limit_time <= time - $start_time )
		) {
			$epp->send_logout($sid);
			last;
		}

		++$c;

		# determine the type of request according to the specified proportion
		my $req_type = $prob_scale->[ Util::rand_range(99) ];

		# multiple domains can be passed in the check request, the number is specified in the config
		my @domains;
		if ( $req_type eq 'check' ) {
			my $domains_num = $config->{check_domains} ? Util::rand_range(@{ $config->{check_domains} }) : 1;
			for ( 1 .. $domains_num ) {
				push @domains, 'ph0enix'.int(10000000*rand).'.ru';
			}
		}
		else {
			# domain was taken from test database
			push @domains, 'domain-1-1333528984551.ru';
		}


		my $is_success = $req_type eq 'create' 
			? $epp->send_create($sid, @domains)
			: $epp->send_check($sid, @domains);

		$stat->increment($req_type => $is_success, $epp->last_elapsed, $epp->last_rid);

		# each second show the info: how much request passed,  how much left, RPS
		if (time != $cur_time and $thread_num == 1) {
			print $stat->get_stat_line(
				$limit_number 
					? ( 'limit_number' => $limit_number )
					: ( 'limit_time'   => $limit_time )
			);
			select()->flush();
			$cur_time = time;
		}

	}

	return 1;
}









1;

__END__


