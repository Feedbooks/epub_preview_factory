# EPUB Preview Factory

A library that generates EPUB previews from full publications. 

The output is based on the upcoming specification dedicated to previews published by the [IDPF](http://www.idpf.org).

Created by [Feedbooks](http://www.feedbooks.com) with the support of [Centre National du Livre](http://www.centrenationaldulivre.fr/). 

Released under the
MIT license.

## Requirements

Ruby 1.9 or a more recent version.

Install bundler with gem.

In the directory run  "bundle install".

Required Ruby gems:

* zipruby
* nokogiri
* mime-types
* uuid
* thor
* workers

EPUB Preview Factory is based on a fork of [Peregrin](https://github.com/joseph/peregrin) to handle the EPUB side of things.

## Using EPUB Preview Factory

You can list all the available options for EPUB Preview Factory using the command-line:

    $ bundle exec ruby main.rb
    
    Usage:
     main.rb extract -d, --destination=DESTINATION -s, --source=SOURCE
    
    Options:
     -s, --source=SOURCE                          # Source file or directory
     -d, --destination=DESTINATION                # destination file or directory 
     -i, [--identifier=IDENTIFIER]                # force preview identifier
     -p, [--percent=PERCENT]                      # change percent, default 5%
     -w, [--pool-size=POOL_SIZE]                  # change pool size for directory mode, default 5
     -v, [--verbose=VERBOSE]                      # verbose mode
     -c, [--max-char=MAX_CHAR]                    # calcul the size of the extract by char count instead of percent
     -m, [--move-finish-files=MOVE_FINISH_FILES]  # move finished file to the following directory

EPUB Preview Factory has two main modes: single file or batch.

In single file mode (-s pointing to an EPUB), you just need to specify two options: the source file and the destination file. The default option for a preview is to include 5% of the total publication.

    $ bundle exec ruby main.rb extract -s test.epub -d test_preview.epub

In batch mode (-s pointing to a directory), you can specify the number of workers (default option is 5 workers) that you'd like to use to process books faster using the -w option.

## History

* 0.1
  - Initial release
  - Generate preview based on % of the book or total number of characters
  - Use metadata recommendations from the AHL spec (different identifier, link back to original identifier with dc:source, dc:type set to preview)
  - Updates the container, OPF and NCX to only include the content documents that we need
  - Detect images used in content files of the preview and remove other images
