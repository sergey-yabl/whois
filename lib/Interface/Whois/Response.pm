## @file
# @brief basic class for a whois response


## @class Interface::Whois::Response
# @brief basic class for a whois response
package Interface::Whois::Response;
# *********************************************************************

use strict;
use warnings;
use utf8;


# Getters and setters
use Accessor(
	raw               => 'raw',         # response raw string
	is_success        => 'is_success',  # success response flag
	domain            => 'domain',      # domain name
	srv               => 'srv',         # whois host name
	logger            => 'logger',      # Log4Perl object
	error_code        => 'error_code',  # response error code:
	                                    #   TIMEOUT                   - response timeout
	                                    #   NOT_FOUND                 - domain not found
	                                    #   UNKNOWN_RESPONSE_FORMAT   - unknown whois response format
	                                    #   UNKNOWN_ERROR             - any other whois errors
	debug             => 'debug',       # debug flag
);



## @cmethod obj new(hash p)
# basic constructor
# @param p    - \c hash with keys:
# @arg \c raw    - \c string response string
# @arg \c domain - \c string domain name
# @arg \c srv    - \c string whois host name
# @arg \c logger - \c obj Log4Perl object
# @arg \c error  - \c string error string if exist
# @arg \c debug  - \c bool debug flag
sub new
# ----------------------------------------------------------
{
	my ($class, %p) = @_;

	my $self = bless {
		'raw'             => $p{raw} || '',
		'domain'          => $p{domain},
		'srv'             => $p{srv},
		'logger'          => $p{logger},
		'tld'             => (split /\./, $p{domain})[-1],
		'is_success'      => 0,
		'errstr'          => '',
		'debug'           => $p{debug},
		'_parse'          => {},

	}, $class;

	$self->print_debug if $self->debug;

	if ( $p{error} ) {
		$self->error(
			( $p{error} =~ /^Connection timeout/i )
				? 'TIMEOUT'
				: 'UNKNOWN_ERROR'
		);
		return $self;
	}

	$self->_parse_response;

	$self->_init;  # init specific object fields

	return $self;
}
# ----------------------------------------------------------


# Init specific object field
# ----------------------------------------------------------
sub _init {}
# ----------------------------------------------------------



## @method bool xxx_xxx(hash p)
# одной строкой для чего нужен метод
# @param \c p хэш параметров с ключами:
# @arg \c id      - \c int id сообщения
# @arg \c created - \c string timestamp создания в формате YYYY-MM-DD hh:mm:ss
# @retval \c int id при успешном создании
# @retval \c false при ошибке
# @return \c obj объект Model::Archive
# @note произвольная строка ...
# @note ... продолжение примечания
sub _parse_response {
	my $self = shift;

	# domain not found
	if ( $self->raw =~ /^Domain not found/ ) {
		return $self->error('NOT_FOUND');
	}

	# success responce should be started by 'Domain Name: ...' string
	unless ( $self->raw =~ /^Domain Name/ ) {
		$self->print_debug;
		return $self->error('UNKNOWN_RESPONSE_FORMAT');
	}

	for my $line (split /\n/, $self->raw) {

		my ($key, $val) = map { Util::trim($_) } split(':', $line, 2);

		next unless ($key);

		$key = lc $key;

		# for a milti-value param save it as array
		if ( $self->{_parse}{$key} ) {

			#Util::debug([
			#	$self->{_parse}{$key},
			#	ref $self->{_parse}{$key}
			#]);

			$self->{_parse}{$key} = [ $self->{_parse}{$key} ] 
				if ref $self->{_parse}{$key} ne 'ARRAY';

			push @{ $self->{_parse}{$key} }, $val;
			next;
		}

		$self->{_parse}{$key} = $val;

	}

	$self->{is_success} = 1;

	return 1;
}


## @method list domain_status(void)
# return list of the domain statuses
# @return \c list domain statuses, may be empty
sub domain_status {
	my $self = shift;

	# Domain Status: clientDeleteProhibited https://icann.org/epp#clientDeleteProhibited
	# Domain Status: clientTransferProhibited https://icann.org/epp#clientTransferProhibited

	# Util::debug( [grep { !/^http/ } split( /\s+/, $self->{_parse}{'Domain Status'} )] );
	my $raw_status = $self->{_parse}{'domain status'};
	unless (ref $raw_status) {
		$raw_status = [ $raw_status ];
	}

	my @result;

	for my $line ( @$raw_status ) {
		push @result, ( split( /\s+/, $line ) )[0];
	}

	return @result;
}




## @method bool error(string error_code)
# save the error code event and return false (you can throw up that value to a call stack)
sub error {
	my ($self, $error_code) = @_;
	$self->{error_code} = $error_code;
	return 0;
}


## @method bool print_debug(void)
# print whois response into debug.log file
# @return \c true
sub print_debug {
	my $self = shift;

	Util::debug( "\n\n\n"
		. $self->srv .': '.$self->domain 
		. "\n-------START RESPONSE---------------\n"
		. $self->raw
		. "\n-------END RESPONSE-----------------\n"
	);

	return 1;
}

1;


__END__


raw: Domain Name: key-systems.info                                                                                                                            [28/304]
Registry Domain ID: 34174bbd0b914eb7ab93c48daeef7dee-DONUTS
Registrar WHOIS Server: key-systems.net
Registrar URL: http://key-systems.net
Updated Date: 2021-07-31T22:29:36Z
Creation Date: 2001-07-31T17:05:12Z
Registry Expiry Date: 2022-07-31T17:05:12Z
Registrar: Key-Systems GmbH
Registrar IANA ID: 269
Registrar Abuse Contact Email: abuse@key-systems.net
Registrar Abuse Contact Phone: +49 6894 9396 850
Domain Status: clientTransferProhibited https://icann.org/epp#clientTransferProhibited
Registry Registrant ID: REDACTED FOR PRIVACY
Registrant Name: REDACTED FOR PRIVACY
Registrant Organization: c/o whoisproxy.com
Registrant Street: REDACTED FOR PRIVACY
Registrant City: REDACTED FOR PRIVACY
Registrant State/Province: VA
Registrant Postal Code: REDACTED FOR PRIVACY
Registrant Country: US
Registrant Phone: REDACTED FOR PRIVACY
Registrant Phone Ext: REDACTED FOR PRIVACY
Registrant Fax: REDACTED FOR PRIVACY
Registrant Fax Ext: REDACTED FOR PRIVACY
Registrant Email: Please query the RDDS service of the Registrar of Record identified in this output for information on how to contact the Registrant, Admin, or Tech
contact of the queried domain name.
Registry Admin ID: REDACTED FOR PRIVACY
Admin Name: REDACTED FOR PRIVACY
Admin Organization: REDACTED FOR PRIVACY
Admin Street: REDACTED FOR PRIVACY
Admin City: REDACTED FOR PRIVACY
Admin State/Province: REDACTED FOR PRIVACY










Domain Name: key-systems.info
Registry Domain ID: 34174bbd0b914eb7ab93c48daeef7dee-DONUTS
Registrar WHOIS Server: key-systems.net
Registrar URL: http://key-systems.net
Updated Date: 2021-07-31T22:29:36Z
Creation Date: 2001-07-31T17:05:12Z
Registry Expiry Date: 2022-07-31T17:05:12Z
Registrar: Key-Systems GmbH
Registrar IANA ID: 269
Registrar Abuse Contact Email: abuse@key-systems.net
Registrar Abuse Contact Phone: +49 6894 9396 850
Domain Status: clientTransferProhibited https://icann.org/epp#clientTransferProhibited
Registry Registrant ID: REDACTED FOR PRIVACY
Registrant Name: REDACTED FOR PRIVACY
Registrant Organization: c/o whoisproxy.com
Registrant Street: REDACTED FOR PRIVACY
Registrant City: REDACTED FOR PRIVACY
Registrant State/Province: VA
Registrant Postal Code: REDACTED FOR PRIVACY
Registrant Country: US
Registrant Phone: REDACTED FOR PRIVACY
Registrant Phone Ext: REDACTED FOR PRIVACY
Registrant Fax: REDACTED FOR PRIVACY
Registrant Fax Ext: REDACTED FOR PRIVACY
Registrant Email: Please query the RDDS service of the Registrar of Record identified in this output for information on how to contact the Registrant, Admin, or Tech contact of the queried domain name.
Registry Admin ID: REDACTED FOR PRIVACY
Admin Name: REDACTED FOR PRIVACY
Admin Organization: REDACTED FOR PRIVACY
Admin Street: REDACTED FOR PRIVACY
Admin City: REDACTED FOR PRIVACY
Admin State/Province: REDACTED FOR PRIVACY
Admin Postal Code: REDACTED FOR PRIVACY
Admin Country: REDACTED FOR PRIVACY
Admin Phone: REDACTED FOR PRIVACY
Admin Phone Ext: REDACTED FOR PRIVACY
Admin Fax: REDACTED FOR PRIVACY
Admin Fax Ext: REDACTED FOR PRIVACY
Admin Email: Please query the RDDS service of the Registrar of Record identified in this output for information on how to contact the Registrant, Admin, or Tech contact of the queried domain name.
Registry Tech ID: REDACTED FOR PRIVACY
Tech Name: REDACTED FOR PRIVACY
Tech Organization: REDACTED FOR PRIVACY
Tech Street: REDACTED FOR PRIVACY
Tech City: REDACTED FOR PRIVACY
Tech State/Province: REDACTED FOR PRIVACY
Tech Postal Code: REDACTED FOR PRIVACY
Tech Country: REDACTED FOR PRIVACY
Tech Phone: REDACTED FOR PRIVACY
Tech Phone Ext: REDACTED FOR PRIVACY
Tech Fax: REDACTED FOR PRIVACY
Tech Fax Ext: REDACTED FOR PRIVACY
Tech Email: Please query the RDDS service of the Registrar of Record identified in this output for information on how to contact the Registrant, Admin, or Tech contact of the queried domain name.
Name Server: ns3.domaindiscount24.net
Name Server: ns1.domaindiscount24.net
Name Server: ns2.domaindiscount24.net
DNSSEC: unsigned
URL of the ICANN Whois Inaccuracy Complaint Form: https://www.icann.org/wicf/
>>> Last update of WHOIS database: 2022-03-23T21:07:51Z <<<

For more information on Whois status codes, please visit https://icann.org/epp

Terms of Use: Donuts Inc. provides this Whois service for information purposes, and to assist persons in obtaining information about or related to a domain name registration record. Donuts does not guarantee its accuracy. Users accessing the Donuts Whois service agree to use the data only for lawful purposes, and under no circumstances may this data be used to: a) allow, enable, or otherwise support the transmission by e-mail, telephone, or facsimile of mass unsolicited, commercial advertising or solicitations to entities other than the registrar's own existing customers and b) enable high volume, automated, electronic processes that send queries or data to the systems of Donuts or any ICANN-accredited registrar, except as reasonably necessary to register domain names or modify existing registrations. When using the Donuts Whois service, please consider the following: The Whois service is not a replacement for standard EPP commands to the SRS service. Whois is not considered authoritative for registered domain objects. The Whois service may be scheduled for downtime during production or OT&E maintenance periods. Queries to the Whois services are throttled. If too many queries are received from a single IP address within a specified time, the service will begin to reject further queries for a period of time to prevent disruption of Whois service access. Abuse of the Whois system through data mining is mitigated by detecting and limiting bulk query access from single sources. Where applicable, the presence of a [Non-Public Data] tag indicates that such data is not made publicly available due to applicable data privacy laws or requirements. Should you wish to contact the registrant, please refer to the Whois records available through the registrar URL listed above. Access to non-public data may be provided, upon request, where it can be reasonably confirmed that the requester holds a specific legitimate interest and a proper legal basis for accessing the withheld data. Access to this data can be requested by submitting a request via the form found at https://donuts.domains/about/policies/whois-layered-access/ Donuts Inc. reserves the right to modify these terms at any time. By submitting this query, you agree to abide by this policy.