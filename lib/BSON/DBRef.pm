use 5.010001;
use strict;
use warnings;

package BSON::DBRef;
# ABSTRACT: BSON type wrapper for MongoDB DBRefs

use version;
our $VERSION = 'v1.8.2';

use Tie::IxHash;
use Moo 2.002004;
use namespace::clean -except => 'meta';

use BSON ();

=attr id

Required. The C<_id> value of the referenced document. If the
C<_id> is an ObjectID, then you must use a L<BSON::OID> object.

=cut

# no type constraint since an _id can be anything
has id => (
    is        => 'ro',
    required  => 1
);

=attr ref

Required. The name of the collection in which the referenced document
lives.  Either a L<MongoDB::Collection> object or a string containing the
collection name. The object will be coerced to string form.

This may also be specified in the constructor as C<'$ref'>.

=cut

has 'ref' => (
    is        => 'ro',
    required  => 1,
    coerce    => sub { CORE::ref($_[0]) eq 'MongoDB::Collection' ? $_[0]->name : $_[0] },
    isa       => sub { die "must be a non-empty string" unless defined($_[0]) && length($_[0]) },
);

=attr db

Optional. The database in which the referenced document lives. Either a
L<MongoDB::Database> object or a string containing the database name. The
object will be coerced to string form.

Not all other language drivers support the C<$db> field, so using this
field is not recommended.

This may also be specified in the constructor as C<'$db'>.

=cut

has db => (
    is        => 'ro',
    coerce    => sub { CORE::ref($_[0]) eq 'MongoDB::DataBase' ? $_[0]->name : $_[0] },
    isa       => sub { return if ! defined($_[0]); die "must be a non-empty string" unless length($_[0]) },
);

=attr extra

Optional.  A hash reference of additional fields in the DBRef document.
Not all MongoDB drivers support this feature and you B<should not> rely on
it.  This attribute exists solely to ensure DBRefs generated by drivers that
do allow extra fields will round-trip correctly.

B<USE OF THIS FIELD FOR NEW DBREFS IS NOT RECOMMENDED.>

=cut

has extra => (
    is => 'ro',
    isa => sub { return if ! defined($_[0]); die "must be a hashref" unless eval { scalar %{$_[0]}; 1 } },
    default => sub { {} },
);

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my $hr    = $class->$orig(@_);
    return {
        id => (
              exists( $hr->{'$id'} ) ? delete $hr->{'$id'}
            : exists( $hr->{id} )    ? delete $hr->{id}
            :                          undef
        ),
        'ref' => (
              exists( $hr->{'$ref'} ) ? delete $hr->{'$ref'}
            : exists( $hr->{'ref'})    ? delete $hr->{'ref'}
            :                           undef
        ),
        db => (
              exists( $hr->{'$db'} ) ? delete $hr->{'$db'}
            : exists( $hr->{db} )    ? delete $hr->{db}
            :                          undef
        ),
        extra => $hr,
    };
};

sub _ordered {
    my $self = shift;

    return Tie::IxHash->new(
        '$ref' => $self->ref,
        '$id'  => $self->id,
        ( defined($self->db) ? ( '$db' => $self->db ) : () ),
        %{ $self->extra },
    );
}

=method TO_JSON

If the C<BSON_EXTJSON> option is true, returns a hashref compatible with
MongoDB's L<extended JSON|https://github.com/mongodb/specifications/blob/master/source/extended-json.rst>
format, which represents it as a document as follows:

    { "$ref": "<collection name>", "$id": "<id>" }

If the C<BSON_EXTJSON> option is false, an error is thrown, as this value
can't otherwise be represented in JSON.

=cut

sub TO_JSON {
    my $self = shift;

    if ( $ENV{BSON_EXTJSON} ) {
        my $id = $self->id;

        if (ref $id) {
            $id = $id->TO_JSON;
        }
        else {
            $id = BSON->perl_to_extjson($id);
        }

        my %data;
        tie( %data, 'Tie::IxHash' );
        $data{'$ref'} = $self->ref;
        $data{'$id'} = $id;
        $data{'$db'} = $self->db
            if defined $self->db;

        my $extra = $self->extra;
        $data{$_} = $extra->{$_}
            for keys %$extra;

        return \%data;
    }

    Carp::croak( "The value '$self' is illegal in JSON" );
}

1;

__END__

=for Pod::Coverage BUILDARGS

=head1 SYNOPSIS

    use BSON::Types ':all';

    my $dbref = bson_dbref( $oid, $collection_name );

=head1 DESCRIPTION

This module provides a BSON type wrapper for L<MongoDB Database
References|http://docs.mongodb.org/manual/reference/database-references/>.

A DBRef is a special document format which references another document in
the database.  DBRefs are not the same as foreign keys and do not provide
any referential integrity or constraint checking. For example, a DBRef may
point to a document that no longer exists (or never existed.)

Use of DBRefs is discouraged, so this module is provided for backwards
compatibility.  L<"Manual
references"|https://docs.mongodb.com/manual/reference/database-references/#document-references>
are preferred when there is a need to reference other documents.

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
