# frozen_string_literal: true

require 'pandan/command'
require 'pandan/parser'
require 'pandan/graph'
require 'pandan/xcworkspace'
require 'graphviz'

module Pandan
  class DependencyGraph < Command
    def self.options
      [
        ['--xcworkspace=path/to/workspace', 'If this and xcproject not set, Pandan will try to find a workspace'],
        ['--xcproject=path/to/project', 'Path to project'],
        ['--graphviz', 'Outputs the dependency graph in GraphViz format'],
        ['--image', 'Outputs the dependency graph as a PNG image'],
        ['--filter=expression', 'If set, pandan will select all targets whose name match the regular expression']
      ].concat(super)
    end

    self.summary = <<-DESC
      Saves a dependency graph of the Xcode workspace
    DESC

    def initialize(argv)
      @xcworkspace = argv.option('xcworkspace')
      @xcproject = argv.option('xcproject')
      @xcworkspace ||= XCWorkspace.find_workspace unless @xcproject
      @save_gv = argv.flag?('graphviz')
      @save_png = argv.flag?('image')
      @filter = argv.option('filter')
      @filter ||= '.*' # Match everything
      super
    end

    def validate!
      super
      unless @xcworkspace || @xcproject
        help! 'Could not find the workspace. Try setting it manually using the --xcworkspace or --xcproject option.'
      end

      if `which tred`.empty?
        help! 'Pandan requires GraphViz to generate the dependency graph. '\
              'Please install it, e.g. with Homebrew: `brew install graphviz`.'
      end

      help! 'Please use at least one of --graphviz and --image.' if @save_gv.nil? && @save_png.nil?
    end

    def run
      parser = Parser.new(@xcworkspace, @xcproject, @filter)
      targets = parser.all_targets
      graph = Graph.new(false)
      graph.add_target_info(targets)

      Dir.mktmpdir do |dir|
        tmpfile = File.join(dir, 'dependencies.gv')
        tmpfile_reduced = File.join(dir, 'dependencies_reduced.gv')

        save_gv(graphviz_data(graph), tmpfile)
        `tred #{tmpfile} > #{tmpfile_reduced}` # tred performs a transitive reduction on the graph
        reduced_graph = GraphViz.parse(tmpfile_reduced)

        FileUtils.mv(tmpfile_reduced, 'dependencies.gv') if @save_gv
        save_png(reduced_graph, 'dependencies.png') if @save_png
      end
    end

    private

    def graphviz_data(graph)
      graphviz = GraphViz.new(type: :digraph)

      graph.nodes.each_value do |node|
        next unless node.name.match?(/#{@filter}/)

        target_node = graphviz.add_node(node.name)
        node.neighbors.each do |dependency|
          next unless dependency.name.match?(/#{@filter}/)

          dep_node = graphviz.add_node(dependency.name)
          graphviz.add_edge(target_node, dep_node)
        end
      end
      graphviz
    end

    def save_gv(graphviz_data, filename)
      graphviz_data.output(dot: filename)
    end

    def save_png(graphviz_data, filename)
      graphviz_data.output(png: filename)
    end
  end
end
