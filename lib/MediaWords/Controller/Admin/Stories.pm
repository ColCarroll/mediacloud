package MediaWords::Controller::Admin::Stories;
use Modern::Perl "2012";
use MediaWords::CommonLibs;

use strict;
use warnings;
use base 'Catalyst::Controller';
use JSON;
use List::Util qw(first max maxstr min minstr reduce shuffle sum);
use URI;
use URI::Escape;
use URI::QueryParam;

=head1 NAME

MediaWords::Controller::Stories - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index 

=cut

use constant ROWS_PER_PAGE => 100;

use MediaWords::Tagger;

# list of stories with the given feed id
sub list : Local
{

    my ( $self, $c, $feeds_id ) = @_;

    if ( !$feeds_id )
    {
        die "no feeds id";
    }

    $feeds_id += 0;

    my $p = $c->request->param( 'p' ) || 1;

    my $feed = $c->dbis->find_by_id( 'feeds', $feeds_id );
    $c->stash->{ feed } = $feed;

    my ( $stories, $pager ) = $c->dbis->query_paged_hashes(
        "select s.* from stories s, feeds_stories_map fsm where s.stories_id = fsm.stories_id " .
          "and fsm.feeds_id = $feeds_id " . "and publish_date > now() - interval '30 days' " . "order by publish_date desc",
        [], $p, ROWS_PER_PAGE
    );

    if ( @{ $stories } < ROWS_PER_PAGE )
    {
        ( $stories, $pager ) = $c->dbis->query_paged_hashes(
            "select s.* from stories s, feeds_stories_map fsm where s.stories_id = fsm.stories_id " .
              "and fsm.feeds_id = $feeds_id " . "order by publish_date desc",
            [], $p, ROWS_PER_PAGE
        );
    }

    $c->stash->{ stories }   = $stories;
    $c->stash->{ pager }     = $pager;
    $c->stash->{ pager_url } = $c->uri_for( "/admin/stories/list/$feeds_id" ) . '?';

    $c->stash->{ template } = 'stories/list.tt2';
}

# list of stories with the given tag id
sub tag : Local
{

    my ( $self, $c, $tags_id ) = @_;

    if ( !$tags_id )
    {
        die "no tags_id";
    }

    my $tag = $c->dbis->find_by_id( 'tags', $tags_id );
    $c->stash->{ tag } = $tag;

    my $stories = $c->dbis->query(
        "select * from stories s, stories_tags_maps stm where s.stories_id = stm.stories_id and stm.tags_id = ? " .
          "order by publish_date desc",
        $tags_id
    )->hashes;

    $c->stash->{ stories } = $stories;

    $c->stash->{ template } = 'stories/tag.tt2';
}

# detail page for single story
sub view : Local
{
    my ( $self, $c, $stories_id ) = @_;

    if ( !$stories_id )
    {
        die "no stories id";
    }

    my $story = $c->dbis->find_by_id( 'stories', $stories_id );
    $c->stash->{ story } = $story;

    my @feeds = $c->dbis->query(
        "select f.* from feeds f, feeds_stories_map fsm where f.feeds_id = fsm.feeds_id and fsm.stories_id = ?",
        $stories_id )->hashes;
    $c->stash->{ feeds } = \@feeds;

    my @downloads = $c->dbis->query(
        "select d.* from downloads d where d.type = 'content' " . "    and d.state = 'success' and d.stories_id = ?",
        $stories_id )->hashes;
    $c->stash->{ downloads } = \@downloads;

    my @tags = $c->dbis->query(
        "select t.*, ts.name as tag_set_name from tags t, stories_tags_map stm, tag_sets ts " .
          "where t.tags_id = stm.tags_id and stm.stories_id = ? and t.tag_sets_id = ts.tag_sets_id " .
          "order by t.tag_sets_id",
        $stories_id
    )->hashes;
    $c->stash->{ tags } = \@tags;

    $c->stash->{ storytext } = MediaWords::DBI::Stories::get_text( $c->dbis, $story );

    $c->stash->{ stories_id } = $stories_id;

    $c->stash->{ template } = 'stories/view.tt2';
}

# edit a single story
sub edit : Local
{
    my ( $self, $c, $stories_id ) = @_;

    $stories_id += 0;

    if ( !$stories_id )
    {
        die "no stories id";
    }

    my $form = HTML::FormFu->new(
        {
            load_config_file => $c->path_to() . '/root/forms/story.yml',
            method           => 'post',
            action           => '/admin/stories/edit/' . $stories_id
        }
    );

    # Save the original referer to the edit form so we can get back to that URL later on
    my $el_referer = $form->get_element( { name => 'referer', type => 'Hidden' } );
    unless ( $el_referer->value )
    {
        if ( $c->request->referer )
        {
            $el_referer->value( $c->request->referer );
        }
    }

    my $story = $c->dbis->find_by_id( 'stories', $stories_id );

    $form->default_values( $story );
    $form->process( $c->request );

    if ( !$form->submitted_and_valid )
    {
        $form->stash->{ c }     = $c;
        $c->stash->{ form }     = $form;
        $c->stash->{ template } = 'stories/edit.tt2';
        $c->stash->{ title }    = 'Edit Story';

    }
    else
    {

        # Make a logged update
        my $form_params = { %{ $form->params } };    # shallow copy to make editable
        delete $form_params->{ referer };

        # Only 'publish_date' is needed
        delete $form_params->{ publish_date_year };
        delete $form_params->{ publish_date_month };
        delete $form_params->{ publish_date_day };
        delete $form_params->{ publish_date_hour };
        delete $form_params->{ publish_date_minute };
        delete $form_params->{ publish_date_second };

        $c->dbis->update_by_id_and_log(
            'stories',     $stories_id,               $story,             $form_params,
            'story_edits', $form->params->{ reason }, $c->user->username, 'stories_id',
            $stories_id
        );

        # Redirect back to the referer or a story
        my $url        = '';
        my $status_msg = 'Story with ID ' . $story->{ stories_id } . ' has been modified.';

        if ( $form->params->{ referer } )
        {
            my $uri = URI->new( $form->params->{ referer } );
            $uri->query_param_delete( 'status_msg' );
            $uri->query_param_append( 'status_msg' => $status_msg );
            $url = $uri->as_string

        }
        else
        {
            $url = $c->uri_for( '/admin/stories/view/' . $story->{ stories_id }, { status_msg => $status_msg } );

        }

        $c->response->redirect( $url );

    }

}

# delete tag
sub delete_tag : Local
{
    my ( $self, $c, $stories_id, $tags_id, $confirm ) = @_;

    unless ( $stories_id and $tags_id )
    {
        die "incorrectly formed link because must have Stories ID number 
        and Tags ID number. ex: stories/delete_tag/637467/128";
    }

    my $story = $c->dbis->find_by_id( "stories", $stories_id );

    my $tag = $c->dbis->find_by_id( "tags", $tags_id );

    my $status_msg;

    if ( !defined( $confirm ) )
    {
        $c->stash->{ story }    = $story;
        $c->stash->{ tag }      = $tag;
        $c->stash->{ template } = 'stories/delete_tag.tt2';
    }
    else
    {
        if ( $confirm ne 'yes' )
        {
            $status_msg = 'Tag NOT deleted.';
        }
        else
        {
            my $reason = $c->request->params->{ reason };
            unless ( $reason )
            {
                $c->dbis->dbh->rollback;
                die( "Tag NOT deleted.  Reason left blank." );
            }

            # Start transaction
            $c->dbis->dbh->begin_work;

            # Fetch old tags
            my $old_tags = MediaWords::DBI::Stories::get_existing_tags_as_string( $c->dbis, $stories_id );

            # Delete tag
            $c->dbis->query( "DELETE FROM stories_tags_map WHERE tags_id = ?", $tags_id );

            # Fetch old tags
            my $new_tags = MediaWords::DBI::Stories::get_existing_tags_as_string( $c->dbis, $stories_id );

            # Log the new set of tags
            my @changes;
            my $change = {
                edited_field => '_tags',
                old_value    => $old_tags,
                new_value    => $new_tags,
            };
            push( @changes, $change );
            unless (
                $c->dbis->log_changes( 'story_edits', $reason, $c->user->username, \@changes, 'stories_id', $stories_id ) )
            {
                $c->dbis->dbh->rollback;
                die "Unable to log addition of new tags.\n";
            }

            # Things went fine
            $c->dbis->dbh->commit;

            $status_msg = 'Tag \'' . $tag->{ tag } . '\' deleted from this story.';
        }

        $c->response->redirect(
            $c->uri_for( '/admin/stories/view/' . $story->{ stories_id }, { status_msg => $status_msg } ) );
    }
}

# sets up add tag
sub add_tag : Local
{
    my ( $self, $c, $stories_id ) = @_;

    my $story = $c->dbis->find_by_id( "stories", $stories_id );
    $c->stash->{ story } = $story;

    my @tags = $c->dbis->query(
        <<"EOF",
        SELECT t.*
        FROM tags t, stories_tags_map stm
        WHERE t.tags_id = stm.tags_id AND stm.stories_id = ?
EOF
        $stories_id
    )->hashes;
    $c->stash->{ tags } = \@tags;

    my @tagsets = $c->dbis->query( "SELECT ts.* FROM tag_sets ts" )->hashes;
    $c->stash->{ tagsets } = \@tagsets;

    $c->stash->{ template } = 'stories/add_tag.tt2';
}

# executes add tag
sub add_tag_do : Local
{
    my ( $self, $c, $stories_id ) = @_;

    my $story = $c->dbis->find_by_id( "stories", $stories_id );
    $c->stash->{ story } = $story;

    # Start transaction
    $c->dbis->dbh->begin_work;

    # Fetch old tags
    my $old_tags = MediaWords::DBI::Stories::get_existing_tags_as_string( $c->dbis, $stories_id );

    # Add new tag
    my $new_tag = $c->request->params->{ new_tag };
    my $reason  = $c->request->params->{ reason };
    unless ( $new_tag )
    {
        $c->dbis->dbh->rollback;
        die( "Tag NOT added.  Tag name left blank." );
    }
    unless ( $reason )
    {
        $c->dbis->dbh->rollback;
        die( "Tag NOT added.  Reason left blank." );
    }

    my $new_tag_sets_id = $c->request->params->{ tagset };
    if ( !$new_tag_sets_id )
    {
        $new_tag_sets_id = $c->dbis->find_or_create( 'tag_sets', { name => 'manual_term' } )->{ tag_sets_id };
    }

    my $added_tag = $c->dbis->find_or_create(
        "tags",
        {
            tag         => $new_tag,
            tag_sets_id => $new_tag_sets_id,
        }
    );

    my $stm = $c->dbis->create(
        'stories_tags_map',
        {
            tags_id    => $added_tag->{ tags_id },
            stories_id => $stories_id,
        }
    );

    $c->stash->{ added_tag } = $added_tag;

    # Fetch new tags
    my $new_tags = MediaWords::DBI::Stories::get_existing_tags_as_string( $c->dbis, $stories_id );

    # Log the new set of tags
    my @changes;
    my $change = {
        edited_field => '_tags',
        old_value    => $old_tags,
        new_value    => $new_tags,
    };
    push( @changes, $change );
    unless ( $c->dbis->log_changes( 'story_edits', $reason, $c->user->username, \@changes, 'stories_id', $stories_id ) )
    {
        $c->dbis->dbh->rollback;
        die "Unable to log addition of new tags.\n";
    }

    # Things went fine
    $c->dbis->dbh->commit;

    $c->response->redirect(
        $c->uri_for(
            '/admin/stories/add_tag/' . $story->{ stories_id },
            { status_msg => 'Tag \'' . $added_tag->{ tag } . '\' added.' }
        )
    );
}

sub stories_query_json : Local
{
    my ( $self, $c ) = @_;

    say STDERR "starting stories_query_json";

    my $last_stories_id = $c->req->param( 'last_stories_id' );

    my $start_stories_id = $c->req->param( 'start_stories_id' );

    my $show_raw_1st_download = $c->req->param( 'raw_1st_download' );

    $show_raw_1st_download //= 1;

    die " Cannot use both last_stories_id and start_stories_id"
      if defined( $last_stories_id )
      and defined( $start_stories_id );

    if ( defined( $start_stories_id ) && !( defined( $last_stories_id ) ) )
    {
        $last_stories_id = $start_stories_id - 1;
    }
    elsif ( !( defined( $last_stories_id ) ) )
    {
        ( $last_stories_id ) = $c->dbis->query(
" select stories_id from stories where collect_date < now() - interval '1 days' order by collect_date desc limit 1 "
        )->flat;
        $last_stories_id--;
    }

    say STDERR "Last_stories_id is $last_stories_id";

    Readonly my $stories_to_return => min( $c->req->param( 'story_count' ) // 25, 1000 );

    my $query = " SELECT * FROM stories WHERE stories_id > ? ORDER by stories_id asc LIMIT ? ";

    # say STDERR "Running query '$query' with $last_stories_id, $stories_to_return ";

    my $stories = $c->dbis->query( $query, $last_stories_id, $stories_to_return )->hashes;

    foreach my $story ( @{ $stories } )
    {
        my $story_text = MediaWords::DBI::Stories::get_text_for_word_counts( $c->dbis, $story );
        $story->{ story_text } = $story_text;
    }

    foreach my $story ( @{ $stories } )
    {
        my $fully_extracted = MediaWords::DBI::Stories::is_fully_extracted( $c->dbis, $story );
        $story->{ fully_extracted } = $fully_extracted;
    }

    if ( $show_raw_1st_download )
    {
        foreach my $story ( @{ $stories } )
        {
            my $content_ref = MediaWords::DBI::Stories::get_content_for_first_download( $c->dbis, $story );

            if ( !defined( $content_ref ) )
            {
                $story->{ first_raw_download_file }->{ missing } = 'true';
            }
            else
            {

                #say STDERR "got content_ref $$content_ref";

                $story->{ first_raw_download_file } = $$content_ref;
            }
        }
    }

    foreach my $story ( @{ $stories } )
    {
        my $story_sentences = $c->dbis->query( "SELECT * from story_sentences where stories_id = ? ORDER by sentence_number",
            $story->{ stories_id } )->hashes;
        $story->{ story_sentences } = $story_sentences;
    }

    say STDERR "finished stories_query_json";

    $c->response->content_type( 'application/json; charset=UTF-8' );
    return $c->res->body( encode_json( $stories ) );
}

# display regenerated tags for story
sub retag : Local
{
    my ( $self, $c, $stories_id ) = @_;

    my $story = $c->dbis->find_by_id( 'stories', $stories_id );
    my $story_text = MediaWords::DBI::Stories::get_text( $c->dbis, $story );

    my $tags = MediaWords::Tagger::get_all_tags( $story_text );

    $c->stash->{ story }      = $story;
    $c->stash->{ story_text } = $story_text;
    $c->stash->{ tags }       = $tags;
    $c->stash->{ template }   = 'stories/retag.tt2';
}

=head1 AUTHOR

Alexandra J. Sternburg

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
