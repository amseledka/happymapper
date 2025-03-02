# frozen_string_literal: true

require_relative 'lib/happymapper/version'

Gem::Specification.new do |spec|
  spec.name = 'nokogiri-happymapper'
  spec.version = ::HappyMapper::VERSION
  spec.authors = [
    'Damien Le Berrigaud',
    'John Nunemaker',
    'David Bolton',
    'Roland Swingler',
    "Etienne Vallette d'Osia",
    'Franklin Webber',
    'Matijs van Zuijlen'
  ]
  spec.email = 'matijs@matijs.net'

  spec.summary = 'Provides a simple way to map XML to Ruby Objects and back again.'
  spec.description = "Object to XML Mapping Library, using Nokogiri (fork from John Nunemaker's Happymapper)"
  spec.homepage = 'http://github.com/mvz/happymapper'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.6.0'

  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = File.read('Manifest.txt').split
  spec.require_paths = ['lib']

  spec.extra_rdoc_files = ['README.md', 'CHANGELOG.md', 'License']

  spec.add_runtime_dependency 'nokogiri', '~> 1.5'

  spec.add_development_dependency 'pry', '~> 0.14.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rake-manifest', '~> 0.2.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.25'
  spec.add_development_dependency 'rubocop-packaging', '~> 0.5.0'
  spec.add_development_dependency 'rubocop-performance', '~> 1.13'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.9'
  spec.add_development_dependency 'simplecov', '~> 0.21.1'
end
