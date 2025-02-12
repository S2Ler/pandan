# frozen_string_literal: true

require 'pandan/command'
require 'pandan/parser'
require 'pandan/graph'
require 'pandan/xcworkspace'

module Pandan
  class Query < Command
    self.arguments = [
      CLAide::Argument.new('target', true)
    ]

    def self.options
      [
        ['--xcworkspace=path/to/workspace', 'If this and xcproject not set, Pandan will try to find a workspace'],
        ['--xcproject=path/to/project', 'Path to project'],
        ['--reverse', 'If set, pandan will output the targets that depend on the argument'],
        ['--implicit-dependencies', 'If set, pandan will look up for linker flags in all build configurations'],
        ['--comma-separated', 'If set, Pandan outputs a comma-separated list instead of multiple lines'],
        ['--filter=expression', 'If set, pandan will select all targets whose name match the regular expression']
      ].concat(super)
    end

    self.summary = <<-DESC
      Retrieve Xcode dependency information from the target passed as an argument
    DESC

    def initialize(argv)
      @target = argv.shift_argument
      @xcworkspace = argv.option('xcworkspace')
      @xcproject = argv.option('xcproject')
      @xcworkspace ||= XCWorkspace.find_workspace unless @xcproject
      @reverse = argv.flag?('reverse')
      @implicit_deps = argv.flag?('implicit-dependencies')
      @comma_separated = argv.flag?('comma-separated')
      @filter = argv.option('filter')
      @filter ||= '.*' # Match everything
      super
    end

    def validate!
      super
      help! 'A target is required to retrieve the dependency information' unless @target

      unless @xcworkspace || @xcproject
        help! 'Could not find the workspace. Try setting it manually using the --xcworkspace option.'
      end
    end

    def run
      parser = Parser.new(@xcworkspace, @xcproject, @filter)
      graph = Graph.new(@reverse)
      targets = parser.all_targets
      graph.add_target_info(targets)
      if @implicit_deps
        ld_flags_info = parser.other_linker_flags
        graph.add_other_ld_flags_info(ld_flags_info)
      end
      deps = graph.resolve_dependencies(@target).map(&:name)
      deps.select! do |dep|
        dep =~ /#{@filter}/
      end

      if @comma_separated
        puts deps.join ','
      else
        puts deps
      end
    end
  end
end
