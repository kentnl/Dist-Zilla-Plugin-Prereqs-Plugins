use 5.008;    # pragma utf8
use strict;
use warnings;
use utf8;

package Dist::Zilla::Plugin::Prereqs::Plugins;

our $VERSION = '1.001000';

# ABSTRACT: Add all Dist::Zilla plugins presently in use as prerequisites.

# AUTHORITY

use Moose qw( with has around );
use Dist::Zilla::Util::ConfigDumper qw( config_dumper );
use MooseX::Types::Moose qw( HashRef ArrayRef Str );

with 'Dist::Zilla::Role::PrereqSource';

=attr C<phase>

The target installation phase to inject into:

=over 4

=item * C<runtime>

=item * C<configure>

=item * C<build>

=item * C<test>

=item * C<develop>

=back

=cut

has phase => ( is => ro =>, isa => Str, lazy => 1, default => sub { 'develop' }, );

=attr C<relation>

The type of dependency relation to create:

=over 4

=item * C<requires>

=item * C<recommends>

=item * C<suggests>

=item * C<conflicts>

Though think incredibly hard before using this last one ;)

=back

=cut

has relation => ( is => ro =>, isa => Str, lazy => 1, default => sub { 'requires' }, );

=attr C<exclude>

Specify anything you want excluded here.

May Be specified multiple times.

    [Prereqs::Plugins]
    exclude = Some::Module::Thingy
    exclude = Some::Other::Module::Thingy

=cut

has exclude => ( is => ro =>, isa => ArrayRef [Str], lazy => 1, default => sub { [] } );

=p_attr C<_exclude_hash>

=cut

has _exclude_hash => ( is => ro =>, isa => HashRef [Str], lazy => 1, builder => '_build__exclude_hash' );

=method C<mvp_multivalue_args>

The list of attributes that can be specified multiple times

    exclude

=cut

sub mvp_multivalue_args { return qw(exclude) }

=p_method C<_build__exclude_hash>

=cut

sub _build__exclude_hash {
  my ( $self, ) = @_;
  return { map { ( $_ => 1 ) } @{ $self->exclude } };
}

=method C<get_plugin_module>

    $instance->get_plugin_module( $plugin_instance );

=cut

sub get_plugin_module {
  my ( undef, $plugin ) = @_;
  return if not ref $plugin;
  require Scalar::Util;
  return Scalar::Util::blessed($plugin);
}

=method C<skip_prereq>

    if ( $instance->skip_prereq( $plugin_instance ) ) {

    }

=cut

sub skip_prereq {
  my ( $self, $plugin ) = @_;
  return 1 if exists $self->_exclude_hash->{ $self->get_plugin_module($plugin) };
  return;
}

=method C<get_prereq_for>

    my ( $module, $version ) = $instance->get_prereq_for( $plugin_instance );

=cut

sub get_prereq_for {
  my ( $self, $plugin ) = @_;
  return ( $self->get_plugin_module($plugin), 0 );
}

around 'dump_config' => config_dumper( __PACKAGE__, qw( phase relation exclude ) );

=method C<register_prereqs>

See L<<< C<< Dist::Zilla::Role::B<PrereqSource> >>|Dist::Zilla::Role::PrereqSource >>>

=cut

sub register_prereqs {
  my ($self)   = @_;
  my $zilla    = $self->zilla;
  my $phase    = $self->phase;
  my $relation = $self->relation;

  for my $plugin ( @{ $self->zilla->plugins } ) {
    next if $self->skip_prereq($plugin);
    my ( $name, $version ) = $self->get_prereq_for($plugin);
    $zilla->register_prereqs( { phase => $phase, type => $relation }, $name, $version );
  }
  return $zilla->prereqs;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

=head1 SYNOPSIS

    [Prereqs::Plugins]
    ; all plugins are now develop.requires deps

    [Prereqs::Plugins]
    phase = runtime    ; all plugins are now runtime.requires deps

=head1 DESCRIPTION

This is mostly because I am lazy, and the lengthy list of hand-updated dependencies
on my C<@Author::> bundle started to get overwhelming, and I'd periodically miss something.

This module is kinda C<AutoPrereqs>y, but in ways that I can't imagine being plausible with
a generic C<AutoPrereqs> tool, at least, not without requiring some nasty re-implementation
of how C<dist.ini> is parsed.

=head1 LIMITATIONS

=over 4

=item * This module will B<NOT> report C<@Bundles> as dependencies at present.

=item * This module will B<NOT> I<necessarily> include B<ALL> dependencies, but is only intended to include the majority of them.

Some plugins, such as my own C<Bootstrap::lib> don't add themselves to the C<dzil> C<< ->plugins() >> list, and as such, it will be invisible to this module.

=back

=cut
