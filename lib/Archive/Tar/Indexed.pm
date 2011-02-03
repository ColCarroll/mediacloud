package Archive::Tar::Indexed;

# allow fast indexed reading of individual files in a tar file as well as fast appending of new files

use strict;

use File::Path;
use File::Temp ();
use Fcntl qw/:flock :seek/;
use POSIX;

# read the given file from the given tar file at the given starting block with the given number of blocks
# return a ref to the file contents.
sub read_file
{
    my ( $tar_file, $file_name, $starting_block, $num_blocks ) = @_;
    
    my $tar_cmd = "dd if='$tar_file' bs=512 skip=$starting_block count=$num_blocks 2> /dev/null | tar -x -O -f - '$file_name'";
    my $content = `$tar_cmd`;
        
    if ( $content eq '' )
    {
        die( "Unable to retrieve content from tar with '$tar_cmd'" );
    }
    
    return \$content;
}

# get the lock file for a given archive. if the directory that contains the file does not exist, create it.
sub _get_lock_file
{
    my ( $tar_file ) = @_;
    
    my $pos_file = File::Spec->tmpdir . "/$tar_file";
    
    my $pos_dir = $pos_file;
    
    $pos_dir =~ s~/[^/]*$~~;
    
    File::Path::mkpath( $pos_dir );
    
    return $pos_file;
}

# if there's no position file, find the starting block to
# append to (the block after the last block of the last file).
#
# this is necessary because tar sticks a variable number of null
# blocks at the end of every tar archive, and we need to put the new
# archive right after the last valid block.  We find the last valid block
# seeking to the end of the file, reading the block, testing whether it
# is a null block, moving back one block if it is not, and so on
# until we find a non-null block.
sub _find_starting_block
{
    my ( $tar_file ) = @_;
    
    if ( ! -f $tar_file ) 
    {
        return 0;
    }
    
    my $tar_size = ( stat( $tar_file ) )[7];
    
    if ( !open( TAR, $tar_file ) )
    {
        die( "unable to open tar file: $!" );
    }
    
    my $pos = $tar_size;
    while ( $pos > 0 )
    {
        seek( TAR, $pos - 512, SEEK_SET );
        my $block;
        if ( !read( TAR, $block, 512 ) )
        {
            die( "Unable to read from tar file: $!" );
        }
        if ( $block =~ /[^\0]/o )
        {
            last;
        }
        else {
            $pos -= 512;
        }
    }
    
    return POSIX::ceil( $pos / 512 );
}

# append the given file contents to the given tar file under the given path.
# returns the starting block and number of blocks for the file, to be passed
# into read_file.
sub append_file
{
    my ( $tar_file, $file_contents_ref, $file_name ) = @_;
    
    if ( $tar_file =~ /[^a-zA-Z0-9_\-]$/ )
    {
        die( "Only [A-Za-z0-9_\-] allowed with tar file name" );
    }

    my $temp_dir = File::Temp::tempdir || die( "Unable to create temp dir" );
    
    my $file_path = $file_name;
    $file_path =~ s~([^/]+)$~~;

    File::Path::mkpath( "$temp_dir/$file_path" );
        
    if ( !open( FILE, "> $temp_dir/$file_name" ) )
    {
        File::Path::rmtree( $temp_dir );
        die( "Unable to open file '$temp_dir/$file_name': $!" );
    }
    
    print FILE ${ $file_contents_ref };
    
    close( FILE );

    my $lock_file = _get_lock_file( $tar_file );
    
    if ( !open( LOCK_FILE, '>', $lock_file ) )
    {
        File::Path::rmtree( $temp_dir );
        die( "Unable to open lock file '$lock_file': $!" );
    }
    
    flock( LOCK_FILE, LOCK_EX );
    
    my @pre_tar_stats = stat( $tar_file );
    
    my $tar_file_mode = ( -f $tar_file ) ? '+<' : '+>';
    if ( !open( TAR_FILE, '>>', $tar_file ) )
    {
        File::Path::rmtree( $temp_dir );
        die( "Unable to open ta file '$tar_file': $!" );
    }
    
    my $tar_cmd = "tar -c -C '$temp_dir' -f - '$file_name'";    
    my $tar_output = `$tar_cmd`;
    
    print TAR_FILE $tar_output;

    close( TAR_FILE );
    
    my @post_tar_stats = stat( $tar_file );
    
    flock( POS_FILE, LOCK_UN );
    close( POS_FILE );

    File::Path::rmtree( $temp_dir );
    
    my $tar_file_len = $post_tar_stats[7] - $pre_tar_stats[7];
    my $num_blocks = $tar_file_len / 512;
    my $starting_block = $pre_tar_stats[7] / 512;
    
    return( $starting_block, $num_blocks );
}

1;