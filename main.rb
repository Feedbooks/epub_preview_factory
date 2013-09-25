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
   method_option :pool_size, :aliases => "-w", :desc => "change pool size for directory mode, default 5"
   method_option :verbose, :aliases => "-v", :desc => "verbose mode"
   method_option :max_char, :aliases => "-c", :desc => "calcul the size of the extract by char count instead of percent"
   method_option :move_finish_files, :aliases => "-m", :desc => "move finished file to the following directory"
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

      if !options[:move_finish_files].nil?
        if File.exists?(options[:move_finish_files])
          if !File.directory?(options[:move_finish_files])
            puts "the move directory is not a directory"
            exit(1)
          else
            move_directory = Dir.new(options[:move_finish_files])
          end
        else
          FileUtils.mkdir(options[:move_finish_files])
          move_directory = Dir.new(options[:move_finish_files])
        end
      end

      dir_source.each do |book|
        pool.perform do
          source_path = dir_source.path + '/' + book
          dest_path = (dir_dest.path + '/' + book).gsub(' ', '_')
          next if File.directory?(book) || File.extname(book) != '.epub'
          puts "trying generating #{dest_path}" if verbose
          begin
            extract = Extractor.new(source_path, percent)
            if !options[:max_char].nil?
              extract.set_max_word(options[:max_char].to_i)
            end
            extract.get_extract(dest_path)
            FileUtils.rm_rf(dest_path.gsub('.epub', ''))
            puts "succefully generating #{dest_path}" if verbose
            unless move_directory.nil?
              FileUtils.move(source_path, move_directory)
            end
          rescue
            puts "failed to generate #{source_path}" if verbose
            next
          end
        end
      end

      pool.shutdown do
        puts "Worker thread #{Thread.current.object_id} is shutting down." if verbose
      end

      pool.join
    else
      extract = Extractor.new(options[:source], percent)
      if !options[:max_word].nil?
        extract.set_max_word(options[:max_char].to_i)
      end
      if options[:identifier]
        extract.set_book_identifier(options[:identifier])
      end
      extract.get_extract(options[:destination])
      FileUtils.rm_rf(options[:destination].gsub('.epub', ''))
    end
  end
end

App.start
