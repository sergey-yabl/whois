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
	_raw              => '_raw',       # response raw string
	is_success        => 'is_success',
	errstr            => 'errstr',
);


## @cmethod obj new(string raw, string domain)
# basic constructor
# @param raw    - \c string response string
# @param domain - \c string domain name
sub new
# ----------------------------------------------------------
{
	my ($class, $raw, $domain) = @_;

	my $self = bless {
		'raw'             => $raw,
		'tld'             => (split /\./, $domain)[-1],
		'is_success'      => undef,
		'errstr'          => '',
	}, $class;


	$self->_init;  # init specific object fields

	return $self;
}
# ----------------------------------------------------------


# Init specific object field
# ----------------------------------------------------------
sub _init {}
# ----------------------------------------------------------





1;
