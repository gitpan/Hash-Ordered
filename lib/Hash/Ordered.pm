use 5.006;
use strict;
use warnings;

package Hash::Ordered;
# ABSTRACT: A compact, pure-Perl ordered hash class
our $VERSION = '0.001'; # VERSION

use Carp ();
use List::Util 1.09 ();

use constant {
    _DATA => 0,
    _KEYS => 1,
};

use overload 'bool' => sub { scalar @{ $_[0]->[_KEYS] } }, fallback => 1;

#pod =method new
#pod
#pod     $oh = Hash::Ordered->new;
#pod     $oh = Hash::Ordered->new( @pairs );
#pod
#pod Constructs an object, with an optional list of key-value pairs.
#pod
#pod =cut

sub new {
    my ( $class, @pairs ) = @_;

    return bless [ {}, [] ], $class unless @pairs;

    Carp::croak("new() requires key-value pairs") unless @pairs % 2 == 0;

    my $self = [ {@pairs}, [ map { $_ % 2 == 0 ? ( $pairs[$_] ) : () } 0 .. $#pairs ] ];

    return bless $self, $class;
}

#pod =method clone
#pod
#pod     $oh2 = $oh->clone;
#pod     $oh2 = $oh->clone( @keys );
#pod
#pod Creates a shallow copy of an ordered hash object.  If no arguments are
#pod given, it produces an exact copy.  If a list of keys is given, the new
#pod object includes only those keys in the given order.  Keys that aren't
#pod in the original will have the value C<undef>.
#pod
#pod =cut

sub clone {
    my ( $self, @keys ) = @_;
    my $clone;
    if (@keys) {
        my %subhash;
        @subhash{@keys} = @{ $self->[_DATA] }{@keys};
        $clone = [ \%subhash, \@keys ];
    }
    else {
        $clone = [ { %{ $self->[_DATA] } }, [ @{ $self->[_KEYS] } ] ];
    }
    return bless $clone, ref $self;
}

#pod =method keys
#pod
#pod     @keys = $oh->keys;
#pod
#pod Returns the ordered list of keys.
#pod
#pod =cut

sub keys {
    my ($self) = @_;
    return @{ $self->[_KEYS] };
}

#pod =method values
#pod
#pod     @values = $oh->values;
#pod     @values = $oh->values( @keys );
#pod
#pod Returns an ordered list of values.  If no arguments are given, returns
#pod the ordered values of the entire hash.  If a list of keys is given, returns
#pod values in order corresponding to those keys.  If a key does not exist, C<undef>
#pod will be returned for that value.
#pod
#pod =cut

sub values {
    my ( $self, @keys ) = @_;
    return map { $self->[_DATA]{$_} } ( @keys ? @keys : @{ $self->[_KEYS] } );
}

#pod =method get
#pod
#pod     $value = $oh->get("some key");
#pod
#pod Returns the value associated with the key.
#pod
#pod =cut

sub get {
    my ( $self, $key ) = @_;
    return $self->[_DATA]{$key};
}

#pod =method set
#pod
#pod     $oh->set("some key" => "some value");
#pod
#pod Associates a value with a key and returns the value.  If the key does not
#pod already exist in the hash, it will be added at the end.
#pod
#pod =cut

sub set {
    my ( $self, $key, $value ) = @_;
    if ( !exists $self->[_DATA]{$key} ) {
        push @{ $self->[_KEYS] }, $key;
    }
    return $self->[_DATA]{$key} = $value;
}

#pod =method exists
#pod
#pod     if ( $oh->exists("some key") ) { ... }
#pod
#pod Test if some key exists in the hash (without creating it).
#pod
#pod =cut

sub exists {
    my ( $self, $key ) = @_;
    return exists $self->[_DATA]{$key};
}

#pod =method delete
#pod
#pod     $value = $oh->delete("some key");
#pod
#pod Removes a key-value pair from the hash and returns the value.  This
#pod is expensive, as the ordered list of keys has to be updated.
#pod
#pod =cut

sub delete {
    my ( $self, $key ) = @_;
    if ( exists $self->[_DATA]{$key} ) {
        # XXX could put an index on this later if linear search is too slow
        my $r = $self->[_KEYS];
        my $i = List::Util::first { $r->[$_] eq $key } 0 .. $#$r;
        splice @$r, $i, 1;
        return delete $self->[_DATA]{$key};
    }
    return undef; ## no critic
}

#pod =method push
#pod
#pod     $oh->push( one => 1, two => 2);
#pod
#pod Add a list of key-value pairs to the end of the ordered hash.  If a key already
#pod exists in the hash, it will be deleted and re-inserted at the end with the new
#pod value.
#pod
#pod Returns the number of keys after the push is complete.
#pod
#pod =cut

sub push {
    my ( $self, @pairs ) = @_;
    while (@pairs) {
        my ( $k, $v ) = splice( @pairs, 0, 2 );
        if ( exists $self->[_DATA]{$k} ) {
            # splice out key
            # XXX could put an index on this later if linear search is too slow
            my $r = $self->[_KEYS];
            my $i = List::Util::first { $r->[$_] eq $k } 0 .. $#$r;
            splice @$r, $i, 1;
        }
        push @{ $self->[_KEYS] }, $k;
        $self->[_DATA]{$k} = $v;
    }
    return scalar @{ $self->[_KEYS] };
}

#pod =method pop
#pod
#pod     ($key, $value) = $oh->pop;
#pod
#pod Removes and returns the last key-value pair in the ordered hash.
#pod
#pod =cut

sub pop {
    my ($self) = @_;
    my $key = pop @{ $self->[_KEYS] };
    return $key, delete $self->[_DATA]{$key};
}

#pod =method unshift
#pod
#pod     $oh->unshift( one => 1, two => 2 );
#pod
#pod Adds a list of key-value pairs to the beginning of the ordered hash.  If a key
#pod already exists, it will be deleted and re-inserted at the beginning with the
#pod new value.
#pod
#pod Returns the number of keys after the unshift is complete.
#pod
#pod =cut

sub unshift {
    my ( $self, @pairs ) = @_;
    while (@pairs) {
        my ( $k, $v ) = splice( @pairs, -2, 2 );
        if ( exists $self->[_DATA]{$k} ) {
            # splice out key
            # XXX could put an index on this later if linear search is too slow
            my $r = $self->[_KEYS];
            my $i = List::Util::first { $r->[$_] eq $k } 0 .. $#$r;
            splice @$r, $i, 1;
        }
        unshift @{ $self->[_KEYS] }, $k;
        $self->[_DATA]{$k} = $v;
    }
    return scalar @{ $self->[_KEYS] };
}

#pod =method shift
#pod
#pod     ($key, $value) = $oh->shift;
#pod
#pod Removes and returns the first key-value pair in the ordered hash.
#pod
#pod =cut

sub shift {
    my ($self) = @_;
    my $key = shift @{ $self->[_KEYS] };
    return $key, delete $self->[_DATA]{$key};
}

#pod =method merge
#pod
#pod     $oh->merge( one => 1, two => 2 );
#pod
#pod Merges a list of key-value pairs into the ordered hash.  If a key already
#pod exists, its value is replaced.  Otherwise, the key-value pair is added at
#pod the end of the hash.
#pod
#pod =cut

sub merge {
    my ( $self, @pairs ) = @_;
    while (@pairs) {
        my ( $k, $v ) = splice( @pairs, -2, 2 );
        if ( !exists $self->[_DATA]{$k} ) {
            CORE::push @{ $self->[_KEYS] }, $k;
        }
        $self->[_DATA]{$k} = $v;
    }
    return scalar @{ $self->[_KEYS] };
}

#pod =method as_list
#pod
#pod     @pairs = $oh->as_list;
#pod     @pairs = $oh->as_list( @keys );
#pod
#pod Returns an ordered list of key-value pairs. If no arguments are given, all
#pod pairs in the hash are returned.  If a list of keys is given, the returned list
#pod includes only those key-value pairs in the given order.  Keys that aren't in
#pod the original will have the value C<undef>.
#pod
#pod =cut

sub as_list {
    my ( $self, @keys ) = @_;
    @keys = @{ $self->[_KEYS] } unless @keys;
    return map { ; $_ => $self->[_DATA]{$_} } @keys;
}

#pod =method iterator
#pod
#pod     $iter = $oh->iterator;
#pod     $iter = $oh->iterator( reverse $oh->keys ); # reverse
#pod
#pod     while ( my ($key,$value) = $iter->() ) { ... }
#pod
#pod Returns a code reference that returns a single key-value pair (in order) on
#pod each invocation, or the empty list if all keys are visited.
#pod
#pod If no arguments are given, the iterator walks the entire hash in order.  If a
#pod list of keys is provided, the iterator walks the hash in that order. Unknown
#pod keys will return C<undef>.
#pod
#pod The list of keys to return is set when the iterator is generator.  Keys added
#pod later will not be returned.  Delete keys will return C<undef>.
#pod
#pod =cut

sub iterator {
    my ( $self, @keys ) = @_;
    @keys = @{ $self->[_KEYS] } unless @keys;
    my $data = $self->[_DATA];
    return sub {
        return unless @keys;
        my $key = CORE::shift(@keys);
        return ( $key => $data->{$key} );
    };
}

1;


# vim: ts=4 sts=4 sw=4 et:

__END__

=pod

=encoding UTF-8

=head1 NAME

Hash::Ordered - A compact, pure-Perl ordered hash class

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    use Hash::Ordered;

    my $oh = Hash::Ordered->new( a => 1 );

    $oh->get( 'a' );
    $oh->set( 'a' => 2 );

    $oh->exists( 'a' );
    $val = $oh->delete( 'a' );

    @keys  = $oh->keys;
    @vals  = $oh->values;
    @pairs = $oh->as_list

    $oh->push( c => 3, d => 4 );
    $oh->unshift( e => 5, f => 6 );

    ( $k, $v ) = $oh->pop;
    ( $k, $v ) = $oh->shift;

    $iter = $oh->iterator;
    while( ( $k, $v ) = $iter->() ) { ... }

    $copy     = $oh->clone;
    $subset   = $oh->clone( qw/c d/ );
    $reversed = $oh->clone( reverse $oh->keys );

    @value_slice = $oh->values(  qw/c f/ ); # qw/3 6/
    @pairs_slice = $oh->as_list( qw/f e/ ); # qw/f 6 e 5/

=head1 DESCRIPTION

This module implements an ordered hash, meaning that it associates keys with
values like a Perl hash, but keeps the keys in a consistent order.  Because it
is implemented as an object and manipulated with method calls, it is much
slower than a Perl hash.  This is the cost of keeping order.

=head1 METHODS

=head2 new

    $oh = Hash::Ordered->new;
    $oh = Hash::Ordered->new( @pairs );

Constructs an object, with an optional list of key-value pairs.

=head2 clone

    $oh2 = $oh->clone;
    $oh2 = $oh->clone( @keys );

Creates a shallow copy of an ordered hash object.  If no arguments are
given, it produces an exact copy.  If a list of keys is given, the new
object includes only those keys in the given order.  Keys that aren't
in the original will have the value C<undef>.

=head2 keys

    @keys = $oh->keys;

Returns the ordered list of keys.

=head2 values

    @values = $oh->values;
    @values = $oh->values( @keys );

Returns an ordered list of values.  If no arguments are given, returns
the ordered values of the entire hash.  If a list of keys is given, returns
values in order corresponding to those keys.  If a key does not exist, C<undef>
will be returned for that value.

=head2 get

    $value = $oh->get("some key");

Returns the value associated with the key.

=head2 set

    $oh->set("some key" => "some value");

Associates a value with a key and returns the value.  If the key does not
already exist in the hash, it will be added at the end.

=head2 exists

    if ( $oh->exists("some key") ) { ... }

Test if some key exists in the hash (without creating it).

=head2 delete

    $value = $oh->delete("some key");

Removes a key-value pair from the hash and returns the value.  This
is expensive, as the ordered list of keys has to be updated.

=head2 push

    $oh->push( one => 1, two => 2);

Add a list of key-value pairs to the end of the ordered hash.  If a key already
exists in the hash, it will be deleted and re-inserted at the end with the new
value.

Returns the number of keys after the push is complete.

=head2 pop

    ($key, $value) = $oh->pop;

Removes and returns the last key-value pair in the ordered hash.

=head2 unshift

    $oh->unshift( one => 1, two => 2 );

Adds a list of key-value pairs to the beginning of the ordered hash.  If a key
already exists, it will be deleted and re-inserted at the beginning with the
new value.

Returns the number of keys after the unshift is complete.

=head2 shift

    ($key, $value) = $oh->shift;

Removes and returns the first key-value pair in the ordered hash.

=head2 merge

    $oh->merge( one => 1, two => 2 );

Merges a list of key-value pairs into the ordered hash.  If a key already
exists, its value is replaced.  Otherwise, the key-value pair is added at
the end of the hash.

=head2 as_list

    @pairs = $oh->as_list;
    @pairs = $oh->as_list( @keys );

Returns an ordered list of key-value pairs. If no arguments are given, all
pairs in the hash are returned.  If a list of keys is given, the returned list
includes only those key-value pairs in the given order.  Keys that aren't in
the original will have the value C<undef>.

=head2 iterator

    $iter = $oh->iterator;
    $iter = $oh->iterator( reverse $oh->keys ); # reverse

    while ( my ($key,$value) = $iter->() ) { ... }

Returns a code reference that returns a single key-value pair (in order) on
each invocation, or the empty list if all keys are visited.

If no arguments are given, the iterator walks the entire hash in order.  If a
list of keys is provided, the iterator walks the hash in that order. Unknown
keys will return C<undef>.

The list of keys to return is set when the iterator is generator.  Keys added
later will not be returned.  Delete keys will return C<undef>.

=head1 OVERLOADING

=head2 Boolean

    if ( $oh ) { ... }

When used in boolean context, a Hash::Ordered object is true if it has any entries
and false otherwise.

=head1 MOTIVATION

For a long time, I used L<Tie::IxHash> for ordered hashes, but I grew
frustrated with things it lacked, like a cheap way to copy an IxHash object or
a convenient iterator when not using the tied interface.  As I looked at its
implementation, it seemed more complex than I though it needed, with an extra
level of indirection that slows data access.

Given that frustration, I started experimenting with the simplest thing I
thought could work for an ordered hash.

As I worked on this, I also started searching for other modules doing similar
things.  What I found fell broadly into two camps: modules based on tie (even
if they offered an OO interface), and pure OO modules.  They all either lacked
features I deemed necessary or else seemed overly complex in either
implementation or API.

Hash::Ordered attempts to find the sweet spot with simple implementation,
reasonably good efficiency for most common operations, and a rich, intuitive
API.

=head1 SEE ALSO

=head2 Tie modules

The following modules offer some sort of tie interface.  I don't like ties, in
general, because of the extra indirection involved over a direct method call, but
if that doesn't bother you, you might want to try one of these

L<Tie::IxHash> is probably the most well known and includes an OO API.  If its
warts and performance profile aren't a problem, it might serve.

L<Tie::LLHash> I haven't used, but the linked-list implementation might be
worthwhile if you expect to do a lot of deletions.

L<Tie::Hash::Indexed> is implemented in XS and thus seems promising if pure-Perl
isn't a criterion, but last I looked, it had a lot of CPAN Testers failures,
which lowers my trust in it.

These other modules have very specific designs/limitations and I didn't find
any of them suitable for general purpose use:

=over 4

=item *

L<Tie::Array::AsHash> — array elements split with separator; tie API only

=item *

L<Tie::Hash::Array> — ordered alphabetically; tie API only

=item *

L<Tie::InsertOrderHash> — ordered by insertion; tie API only

=item *

L<Tie::StoredOrderHash> — ordered by last update; tie API only

=back

=head2 Other ordered hash modules

Other modules stick with an object-oriented API, with a wide variety of
implementation approaches.

L<Array::AsHash> is essentially an inverse implementation from Hash::Ordered.
It keeps pairs in an array and uses a hash to index into the array.  I think
this indirection makes hash-like operations slower, but getting the list of
pairs back out is much faster.  It takes an arrayref to initialize, but can
shallow copy it if needed.  I think this is a reasonable alternative if static
construction and listing out contents is more common than individual item
access.

These other modules have restrictions or particularly complicated
implementations (often relying on C<tie>) and thus I didn't think any of them
suitable for general purpose use:

=over 4

=item *

L<Array::Assign> — arrays with named access; restricted keys

=item *

L<Array::OrdHash> — overloads array/hash deref and uses internal tied data

=item *

L<Data::Pairs> — array of key-value hashrefs; allows duplicate keys

=item *

L<Data::OMap> — array of key-value hashrefs; no duplicate keys

=item *

L<Data::XHash> — blessed, tied hashref with doubly-linked-list

=back

=for :stopwords cpan testmatrix url annocpan anno bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/dagolden/Hash-Ordered/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/dagolden/Hash-Ordered>

  git clone https://github.com/dagolden/Hash-Ordered.git

=head1 AUTHOR

David Golden <dagolden@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2014 by David Golden.

This is free software, licensed under:

  The Apache License, Version 2.0, January 2004

=cut
