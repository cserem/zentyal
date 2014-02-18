# Copyright (C) 2010-2014 Zentyal S.L.
#
# Based on Plack::Middleware::StackTrace by Tokuhiro Matsuno and Tatsuhiko Miyagawa
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
use strict;
use warnings;

package EBox::Middleware::UnhandledError;
use parent qw/Plack::Middleware/;

use EBox::View::StackTrace;

use Devel::StackTrace;
use Plack::Util::Accessor qw( force no_print_errors );
use TryCatch::Lite;

sub munge_error {
    my($err, $caller) = @_;
    return $err if ref $err;

    # Ugly hack to remove " at ... line ..." automatically appended by perl
    # If there's a proper way to do this, please let me know.
    $err =~ s/ at \Q$caller->[1]\E line $caller->[2]\.\n$//;

    return $err;
}

sub no_trace_error {
    my ($msg) = @_;
    chomp($msg);

    return <<EOF;
The application raised the following error:

  $msg

and the UnhandleError middleware couldn't catch its stack trace.
EOF

}

sub call
{
    my($self, $env) = @_;

    my $trace;
    local $SIG{__DIE__} = sub {
        $trace = Devel::StackTrace->new(
            indent         => 1,
            message        => munge_error($_[0], [ caller ]),
            ignore_package => __PACKAGE__,
        );
        die @_;
    };

    my $res;
    try {
        $res = $self->app->($env);
    } catch ($e) {
        # This $res will only be used if $trace is undef
        $res = [500, ['Content-Type' => 'text/plain; charset=utf-8'], [no_trace_error($e)]];
    }

    if ($trace) {
        $res = [500, ['Content-Type' => 'text/html; charset=utf-8'], [$trace->as_html()]];
    }

    # break $trace here since $SIG{__DIE__} holds the ref to it, and
    # $trace has refs to Standalone.pm's args ($conn etc.) and
    # prevents garbage collection to be happening.
    undef $trace;

    return $res;
}

1;
