## @file
# @brief make getters and setters methods
# Accessor implementation

## @package Accessor
# @brief make getters and setters methods
package Accessor;
# *********************************************************************

use strict;
use warnings;
use utf8;

use vars qw(%attr $VERSION);

# Create methods for accessing object fields
# the field can include two levels of nesting (separator: character '/')
# field starting with "+" will be writable
sub import
# ----------------------------------------------------------
{
	my $class = shift;
	my $package = caller(0);

	return _make($package, @_);
}
# ----------------------------------------------------------


# Create methods for accessing object fields
# the field can include two levels of nesting (separator: character '/')
# field starting with "+" will be writable
sub _make
# ----------------------------------------------------------
{
	my $package = shift;
	my %method2field = @_;

	while ( my($method, $field) = each %method2field ) {
			no strict "refs";
			next if defined *{$package.'::'.$method}; # Method already exitst
			# names of overwritten fields start with a '+' sign: determine the type of the field and remove the service character
			my $is_rewritable = $field =~ s/^\+//;
			my ($key1, $key2) = split m|/|, $field, 2;

			*{$package.'::'.$method} = $is_rewritable
					? $key2
							? sub { $_[0]->{$key1}{$key2} = $_[1] if exists $_[1] ; $_[0]->{$key1}{$key2}}
							: sub { $_[0]->{$key1} = $_[1] if exists $_[1] ; $_[0]->{$key1}}
					: $key2
							? sub { $_[0]->{$key1}{$key2}}
							: sub { $_[0]->{$key1}};
	}

}
# ----------------------------------------------------------


1;