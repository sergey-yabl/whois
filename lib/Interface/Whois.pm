## @file
# @brief Whois interface class


## @package Interface::Whois
# @brief Whois interface class
package Interface::Whois;
# *********************************************************************

use strict;
use warnings;
use utf8;

use Net::Whois::Raw;
use Interface::Whois::Response;

$Net::Whois::Raw::TIMEOUT = 5;


use Accessor(
	logger          => 'logger',
	servers         => 'servers',
	cache           => 'cache',
	debug           => 'debug',
	errstr          => 'errstr',
);



## @cmethod object new(hash %p)
# constructor
# @param p parameter hash with keys:
# @arg \c logger - \c Log4perl logging object
# @arg \c debug  - \c bool debug flag to log all requests
# returns an object of class Interface::Whois
sub new
# ----------------------------------------------------------
{
	my ($class, %p) = @_;

	my $self = bless {
		#config   => $p{config},
		logger   => $p{logger},
		debug    => $p{debug},      # debug flag
		servers  => '',             # whois severs list, setup bellow
		cache    => {},             # whois servers cache
		whois    => undef,          # https://whois.icann.org/en/dns-and-whois-how-it-works
		errstr   => '', 
	}, $class;

	$self->{servers} = Util::read_yaml('conf/whois.conf')
		or die('ERROR: Can not read the whois config file: ' . $!);

	return $self;
}
# ----------------------------------------------------------



## @method obj get_info(string domain)
# get domain info from whois
# @param  \c p domain - \c string domain name
# @param  \c p srv    - \c string whois hostname, if don't pass, 
# @return \c obj Interface::Whois::Response is success
# @return \c FALSE if whois server not found
sub get_info {
	my ($self, $domain) = @_;

	$self->reset_error;

	my $srv = $self->get_whois_server($domain)
		or return $self->error('Unknow whois server for the domain "'.$domain.'", skip it and  go to the next line');

	my $info = eval { whois($domain, $srv) };

	$self->logger->error($@) if $@;

	return Interface::Whois::Response->new(
		raw      => $info,
		domain   => $domain,
		logger   => $self->logger,
		srv      => $srv,
		error    => $@,
		debug    => $self->debug,
	);

}


## @method bool reset_error(void)
# reset last error, actually used before make new request
# @return \c true
sub reset_error {
	$_[0]->{errstr} = '';
	return 1;
}


## @method bool error(string errstr)
# save error string and return false (you can throw up that value to a call stack)
sub error {
	my ($self, $errstr) = @_;
	$self->{errstr} = $errstr;
	$self->logger->error($errstr);
	return 0;
}



## @method bool get_whois_server(string domain)
# search whois server for a domain
# @param \c domain - \c string domain name
# @retval \c string whois hostname
# @retval \c false if whois server unknown
sub get_whois_server {
	my ($self, $domain) = @_;

	my $tld = (split /\./, $domain)[-1];

	return $self->servers->{lc $tld} || '';
}




1;


