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

$Net::Whois::Raw::TIMEOUT = 1;


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
		servers  => {
			org  => 'whois.pir.org',
			info => 'whois.nic.info',
			azia => 'whois.nic.asia',
			biz  => 'whois.nic.biz',
			mobi => 'whois.nic.mobi',
		},
		cache    => {},             # whois servers cache
		whois    => undef,          # https://whois.icann.org/en/dns-and-whois-how-it-works
		errstr   => '', 
	}, $class;

	return $self;
}
# ----------------------------------------------------------



## @method obj get_info(string domain)
# get domain info from whois
# @param  \c p domain - \c string domain name
# @return \c obj Interface::Whois::Response
sub get_info {
	my ($self, $domain) = @_;

	$self->reset_error;

	my $srv = $self->get_whois_server($domain)
		or return $self->error('Unknow whois server for the domain "'.$domain.'", skip it and  go to the next line');

	$self->logger->info($domain .' try to get whois info from srv '.$srv);

	my $info = eval { whois('key-systems.info'), $srv };

	Util::debug([$info, $@]);

	# return $info unless $@;
	return Interface::Whois::Response->new($info, $domain)
		unless $@;

	# Process request error
	$self->logger->error($@);

	# Connection timeout error, try to use alternative way for getting whois info
	if ( $@ =~ /^Connection timeout/ ) {

		return $self->error('Connection timeout to the srv server '.$srv);

		#for ( $self->search_whois($domain) ) {
		#	$self->logger->info($domain .' get whois info');
		#}

	}

	return $self->error('Unknown connection error to the srv server '.$srv);

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


## @method bool get_whois_server(hash p)
# одной строкой для чего нужен метод
# @param \c p хэш параметров с ключами:
# @arg \c id      - \c int id сообщения
# @arg \c created - \c string timestamp создания в формате YYYY-MM-DD hh:mm:ss
# @retval \c int id при успешном создании
# @retval \c false при ошибке
# @return \c obj объект Model::Archive
# @note произвольная строка ...
# @note ... продолжение примечания
sub get_whois_server {
	my ($self, $domain) = @_;

	my $tld = (split /\./, $domain)[-1];

	return $self->servers->{lc $tld};
}




1;


__END__

Error: Connection timeout to whois.afilias.net at /usr/local/share/perl/5.32.1/Net/Whois/Raw.pm line 304, <F> line 2.
 at /usr/local/share/perl/5.32.1/Net/Whois/Raw.pm line 348, <F> line 2.
        Net::Whois::Raw::whois_query("key-systems.info", "whois.afilias.net", 0) called at /usr/local/share/perl/5.32.1/Net/Whois/Raw.pm line 173
        Net::Whois::Raw::recursive_whois("key-systems.info", "whois.afilias.net", ARRAY(0x55f089fc3e18), "", 0) called at /usr/local/share/perl/5.32.1/Net/Whois/Raw.pm line 131
        Net::Whois::Raw::get_all_whois("key-systems.info", undef, "") called at /usr/local/share/perl/5.32.1/Net/Whois/Raw.pm line 100
        Net::Whois::Raw::get_whois("key-systems.info", undef, "QRY_LAST") called at /usr/local/share/perl/5.32.1/Net/Whois/Raw.pm line 81
        Net::Whois::Raw::whois("key-systems.info") called at /home/yabl/work/whois/lib/Interface/Whois.pm line 70
        eval {...} called at /home/yabl/work/whois/lib/Interface/Whois.pm line 70
        Interface::Whois::get_info(Interface::Whois=HASH(0x55f089fc3f68), "key-systems.info") called at ./runner.pl line 160
        Centralnic::Whois::main("in", "domain_list", "domain", undef, "out", undef, "limit", undef, ...) called at ./runner.pl line 98


