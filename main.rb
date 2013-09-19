#!/usr/bin/env ruby
require "rubygems" # ruby1.9 doesn't "require" it though
require "thor"
require 'fileutils'
require 'workers'
require './lib/extractor.rb'

class App < Thor

  desc "extract", "Generate preview from epub"
   method_option :source, :aliases => "-s", :desc => "Source file or directory", :required => true
   method_option :destination, :aliases => "-d", :desc => "destination file or directory ", :required => true
   method_option :identifier, :aliases => "-i", :desc => "force preview identifier"
   method_option :percent, :aliases => "-p", :desc => "change percent, default 5%"
   method_option :pool_size, :aliases => "-ps", :desc => "change pool size for directory mode, default 5"
   method_option :verbose, :aliases => "-v", :desc => "verbose mode"
  def extract
    directory_mode = File.directory?(options[:source])
    percent = options[:percent].to_i
    percent = 5 if percent == 0
    pool_size = options[:pool_size].to_i
    pool_size = 5 if pool_size == 0
    verbose = !options[:verbose].nil?

    if directory_mode
      pool = Workers::Pool.new
      pool.resize(pool_size)
      puts "starting directory mode" if verbose
      if File.exists?(options[:destination])
        if !File.directory?(options[:destination])
          puts "the destination is not a directory"
          exit(1)
        else
          dir_dest = Dir.new(options[:destination])
        end
      else
        FileUtils.mkdir(options[:destination])
        dir_dest = Dir.new(options[:destination])
      end
      dir_source = Dir.new(options[:source])

      dir_source.each do |book|
        pool.perform do
          source_path = dir_source.path + '/' + book
          dest_path = (dir_dest.path + '/' + book).gsub(' ', '_')
          next if File.directory?(book) || File.extname(book) != '.epub'
          begin
            extract = Extractor.new(source_path, percent)
            extract.get_extract(dest_path)
            FileUtils.rm_rf(dest_path.gsub('.epub', ''))
            puts "succefully generating #{dest_path}" if verbose
          rescue
            puts "failed to generate #{source_path}" if verbose
            next
          end
        end
      end
      pool.join
    else
      extract = Extractor.new(options[:source], percent)
      if options[:identifier]
        extract.set_book_identifier(options[:identifier])
      end
      extract.get_extract(options[:destination])
      FileUtils.rm_rf(options[:destination].gsub('.epub', ''))
    end
  end
end

App.start
