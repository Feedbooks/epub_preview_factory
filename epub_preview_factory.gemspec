# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "epub_preview_factory/version"

Gem::Specification.new do |s|
  s.name        = "epub_preview_factory"
  s.version     = EpubPreviewFactory::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Maxim Plourde"]
  s.email       = ["maximp@demarque.com"]
  s.homepage    = ""
  s.summary     = %q{EPUB Preview Factory}
  s.description = %q{A gem that generates EPUB previews from full publications.}

  s.add_dependency "rubyzip"
  s.add_dependency "nokogiri"#, "0.9.1"
  s.add_dependency "mime-types"#, "0.9.2"
  s.add_dependency "uuid"#, "1.8.0"
  s.add_dependency "thor"#, "1.8.0"
  s.add_dependency "workers"#, "1.8.0"
  s.add_dependency "peregrin", "1.2.3"

  s.files         = ["lib/epub_preview_factory.rb", "lib/extractor.rb"]
  s.require_paths = ["lib"]
end
