## @file
# @brief load testing class for EPP


## @package LoadEpp
# @brief load testing class for EPP
package LoadEpp;
# *********************************************************************

use strict;
use warnings;
use utf8;


use HTTP::Request;
use LWP::UserAgent;
use IO::Socket::SSL ; #qw(debug4);

use Accessor(
	config          => 'config',
	logger          => 'logger',
	debug           => 'debug',
	ua              => 'ua',
	req_data        => 'req_data',
	last_rid        => '+last_rid',
	last_logged_rid => '+last_logged_rid',
	last_elapsed    => '+last_elapsed',
);

## @cmethod object new(hash %p)
# constructor
# @param p parameter hash with keys:
# @arg \c config - \c hashref of config data
# @arg \c logger - \c Log4perl logging object
# @arg \c debug - \c bool debug flag to log all requests
# returns an object of class LoadEpp
sub new
# ----------------------------------------------------------
{
	my ($class, %p) = @_;

	my $self = bless {
		config   => $p{config},
		            # config structure:
		            # address: - host and port for requests, for example: https://hoatname.ru:8028
		            # login: - login
		            # registrant: - contact id for domain registration
		            # password: - password
		            # client_cert: - path to client cert
		            # client_key: - path to client cert key
		            # ua_name: - user-agent name, for example test.epp.yabl
		logger   => $p{logger},
		debug    => $p{debug},      # debug flag
		ua       => undef,
		req_data => {},             # xml-templates for EPP requests
		last_rid => '',             # a last client request-id 
		last_logged_rid => '',      # a last logged request
	}, $class;

	$self->_init;
	return $self;
}
# ----------------------------------------------------------



## @method bool _init(void)
# init object fields
sub _init {
	my $self = shift;

	# xml-шаблоны для запросов
	# -------------------------------------
	my %req_data = ();
	my ($key, $buffer);

	my $data = Util::read_data;

	for my $line (split "\n", $data) {
		# pass comments
		next if $line =~ /^\s*#/;

		# a header with request type
		if ($line =~ /^===*(\w+)/) {

			# save what we just read
			$req_data{$key} = Util::trim($buffer)
				if ($key && $buffer);

			# ... and ready to take next part
			$key = Util::trim($1);
			$buffer = '';
			next;
		}

		$buffer .= $line."\n";

	}

	# save a last piece of data
	$req_data{$key} = $buffer
		if ($key && $buffer);

	$self->{req_data} = \%req_data;

	# prepare user agent
	# -------------------------------------
	$self->{ua} = LWP::UserAgent->new(
		agent      => $self->config->{ua_name},
		keep_alive => 30,
		ssl_opts   => {
			SSL_version => "TLSv1",
			SSL_use_cert => 1,
			SSL_cert_file => Util::abs_path($self->config->{client_cert}),
			SSL_key_file  => Util::abs_path($self->config->{client_key}),
			verify_hostname => 0,
			SSL_verify_mode => SSL_VERIFY_NONE
		}
	);

	return 1;
}



## @method bool connect(void)
# init EPP connect
# @retval \c string auth cookie for using in next success requests 
# @retval \c false if error
sub connect {
	my $self = shift;

	$self->send_hello
		or die 'HELLO request failed, cltrid: '.$self->last_rid;

	# auth and get cookie
	my $sid = $self->send_login
		or die 'LOGIN request failed, cltrid: '.$self->last_rid;

	return $sid;
}


## @method bool _send_request(obj req, string type, regexp success_pattern)
# send EPP request
# @param req  - request object HTTP::Request
# @param type - request type: hello, check, create, etc
# @param success_pattern - regexp for result check (success or error)
# @retval response object if success
# @retval FALSE if error appier
sub _request
# ----------------------------------------------------------
{
	my ($self, $req, $type, $success_pattern) = @_;

	# rid is setting up in request methods like  send_xxx
	# because this read should be added in the request body
	# $req->header('x-cltrid'  => $self->_get_new_rid);

	my $t0 = [Time::HiRes::gettimeofday];

	my $res = $self->ua->request($req);

	my $elapsed = sprintf( '%.4f', Time::HiRes::tv_interval ( $t0, [Time::HiRes::gettimeofday]) );

	$self->last_elapsed($elapsed);

	my $svtrid = $res->header('x-svtrid') || '';

	if (!$res->is_success or $res->content !~ $success_pattern) {
		$self->logger->error($type.' failed '.$elapsed.' cltrid:'.$self->last_rid.' svtrid:'.$svtrid);
		$self->log_request($res);
		return 0
	}

	$self->log_request($res) if $self->debug;
	$self->logger->info($type.' success '.$elapsed.' cltrid:'.$self->last_rid.' svtrid:'.$svtrid);

	return $res;
}
# ----------------------------------------------------------



## @method bool send_hello(void)
# send HELLO request
# @return \c obj object HTTP::Response
# @return \c false if error
sub send_hello {
	my $self = shift;

	my $req = HTTP::Request->new(POST => $self->config->{address});

	$req->header('x-cltrid'  => $self->_get_new_rid);

	$req->content($self->req_data->{hello});

	return $self->_request( $req, 'HELLO', qr/greeting/i );
}



## @method bool send_login(void)
# send auth request with credentials from config
# @retval \c string auth cookie for using in next requests 
# @retval \c false if error
sub send_login {
	my $self = shift;

	my $req = HTTP::Request->new(POST => $self->config->{address});

	$req->header('x-cltrid'  => $self->_get_new_rid);

	my $body = Util::replace_xml_tag(
		$self->req_data->{login},
		{
			clID    => $self->config->{login},
			pw      => $self->config->{password},
			clTRID  => $self->last_rid,
		}
	);

	$req->content($body);

	my $res = $self->_request($req, 'LOGIN', qr/result code="1000"/i);

	return $res ? $res->header( 'Set-Cookie' ) : 0;
}



## @method bool send_check(string sid, string domain)
# check if domain if available for registration
# @arg \c sid       - \c string auth cookie
# @arg \c domain    - \c string domain name
# @retval \c true for success
# @retval \c false for error
sub send_check {
	my ($self, $sid, @domains)    = @_;

	my $req = HTTP::Request->new(POST => $self->config->{address});
	$req->header('x-cltrid'  => $self->_get_new_rid);
	$req->header('cookie'    => $sid);

	my $body = Util::replace_xml_tag($self->req_data->{check}, { clTRID  => $self->last_rid } );

	my $domains = '';

	for my $domain (@domains) {
		$domains .= '<domain:name>'.$domain."</domain:name>\n";
	}

	$body =~ s/(<domain:name>)([^<>]+)(<\/domain:name>)/$domains/;

	$req->content($body);

	return $self->_request($req, 'CHECK', qr/result code="1000"/i);
}



## @method bool send_create(string sid, string domain)
# domain registration request
# @arg \c sid       - \c string auth cookie
# @arg \c domain    - \c string domain name for registration
# @retval \c true for succcess
# @retval \c false for error
sub send_create {
	my ($self, $sid, $domain)    = @_;

	my $req = HTTP::Request->new(POST => $self->config->{address});
	$req->header('x-cltrid'  => $self->_get_new_rid);
	$req->header('cookie'    => $sid);

	my $body = Util::replace_xml_tag(
		$self->req_data->{create}, { 
			'clTRID'              => $self->last_rid,
			'domain:name'         => $domain,
			'domain:hostObj'      => 'ns.msk-ix.ru',  # не используется, ns указывать не обязательно поэтому удалил
			'domain:registrant'   => $self->config->{registrant} || 'test1-ru-default',
	} );

	$req->content($body);

	# code 2302 - meand domain is unavailable, its a normal situation, we consider that as success requtsts result
	# otherwice the  request.log will be a larger size (used for logiing all error requests)
	return $self->_request($req, 'CREATE', qr/result code="(1000|2302)"/i);
}



## @method bool send_logout(void)
# end session request
# @retval \c string auth cookie
# @retval \c false if error
sub send_logout {
	my ($self, $sid) = @_;

	my $req = HTTP::Request->new(POST => $self->config->{address});
	$req->header('x-cltrid'  => $self->_get_new_rid);
	$req->header('cookie'    => $sid);

	my $body = Util::replace_xml_tag(
		$self->req_data->{logout},
		{
			clTRID  => $self->last_rid,
		}
	);

	$req->content($body);

	return $self->_request($req, 'LOGOUT', qr/result code="1500"/i);
}


## @method bool _get_new_rid(void)
# make new  request id (rid)
# @retval \c string new rid
sub _get_new_rid {
	my $self = shift;
	$self->last_rid(sprintf('%s.%.6s@'.($self->config->{ua_name} || 'load.test.epp'), Time::HiRes::gettimeofday()));
	return $self->last_rid;
}



## @method void log_request(string rid, obj res)
#  logging request/response data
# @param p hash params:
# @arg \c rid      - id-request
# @arg \c res      - obj object HTTP::Response
sub log_request {
	my ( $self, $res ) = @_;

	my $last_logged_rid = $self->last_logged_rid || '';
	my $request_rid     = $res->{_request}->headers->header('x-cltrid') || '';

	if ( $last_logged_rid && $last_logged_rid eq $request_rid ) {
		return 1;
	}

	my $content = "\n\n\n"
		.Util::get_timestamp."\n"
		."ME >>>>>>>>>>>>>>>>> EPP ".$request_rid."\n"
		.$res->{_request}->as_string
		."\n\n"
		."ME <<<<<<<<<<<<<<<<< EPP ".$request_rid."\n"
		.$res->as_string;

		$self->{request_log_file} ||= Util::abs_path('log/request.log');

		my $open_flag = Encode::is_utf8($content) ? '>>:utf8' : '>>:raw';
		open(W, $open_flag, $self->{request_log_file}) 
			or die("Can not open debug.log file '".$self->{request_log_file}."': ".$!);
		print W $content;
		close W;

	$self->last_logged_rid( $request_rid );

	return 1;
}
# ----------------------------------------------------------

1;

__DATA__
===hello
<?xml version="1.0" encoding="UTF-8"?>
<epp
xmlns="http://www.ripn.net/epp/ripn-epp-1.0"
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:schemaLocation="http://www.ripn.net/epp/ripn-epp-1.0 ripn-epp-1.0.xsd"
>
  <hello/>
</epp>


===login
<?xml version="1.0" encoding="UTF-8"?>
<epp xmlns="http://www.ripn.net/epp/ripn-epp-1.0"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.ripn.net/epp/ripn-epp-1.0 ripn-epp-1.0.xsd">
  <command>
    <login>
      <clID>%login%</clID>
      <pw>%password%</pw>
      <options>
        <version>1.0</version>
        <lang>en</lang>
      </options>
      <svcs>
        <objURI>http://www.ripn.net/epp/ripn-epp-1.0</objURI>
        <objURI>http://www.ripn.net/epp/ripn-eppcom-1.0</objURI>
        <objURI>http://www.ripn.net/epp/ripn-contact-1.0</objURI>
        <objURI>http://www.ripn.net/epp/ripn-domain-1.0</objURI>
        <objURI>http://www.ripn.net/epp/ripn-domain-1.1</objURI>
        <objURI>http://www.ripn.net/epp/ripn-host-1.0</objURI>
        <objURI>http://www.ripn.net/epp/ripn-registrar-1.0</objURI>
      </svcs>
    </login>
    <clTRID>%cltrid%</clTRID>
  </command>
</epp>


===check
<?xml version="1.0" encoding="UTF-8"?>
<epp xmlns="http://www.ripn.net/epp/ripn-epp-1.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.ripn.net/epp/ripn-epp-1.0 ripn-epp-1.0.xsd">
  <command>
    <check>
      <domain:check
        xmlns:domain="http://www.ripn.net/epp/ripn-domain-1.0"
        xsi:schemaLocation="http://www.ripn.net/epp/ripn-domain-1.0 ripn-domain-1.0.xsd">
        <domain:name>%domain%</domain:name>
      </domain:check>
    </check>
    <clTRID>%cltrid%</clTRID>
  </command>
</epp>


===create
<?xml version="1.0" encoding="UTF-8"?>
  <epp xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.ripn.net/epp/ripn-epp-1.0 ripn-epp-1.0.xsd" xmlns="http://www.ripn.net/epp/ripn-epp-1.0">
    <command>
      <create>
        <domain:create 
          xmlns:domain="http://www.ripn.net/epp/ripn-domain-1.0"
          xsi:schemaLocation="http://www.ripn.net/epp/ripn-domain-1.0 ripn-domain-1.0.xsd">
          <domain:name>%domain%</domain:name>
          <domain:period unit="y">1</domain:period>
          <domain:registrant>%registrant%</domain:registrant>
        </domain:create>
      </create>
      <clTRID>%cltrid%</clTRID>
    </command>
  </epp>


===logout
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<epp xmlns="http://www.ripn.net/epp/ripn-epp-1.0"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.ripn.net/epp/ripn-epp-1.0 ripn-epp-1.0.xsd">
 <command>
   <logout/>
   <clTRID>%cltrid%</clTRID>
 </command>
</epp>