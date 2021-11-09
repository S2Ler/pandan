# frozen_string_literal: true

require 'xcodeproj'

module Pandan
  class Parser
    attr_reader :workspace, :workspace_dir, :regex, :project

    def initialize(workspace_path, project_path, filter)
      @workspace_dir = File.dirname(workspace_path) if workspace_path
      @workspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path) if workspace_path

      @project = Xcodeproj::Project.new(project_path) if project_path
      @regex = filter
      @regex ||= '.*' # Match everything
    end

    def all_targets
      @projects ||= projects
      projects.flat_map(&:targets).select { |target| target.name =~ /#{regex}/ }
    end

    def other_linker_flags
      @projects ||= projects
      ld_flags_info = {}
      projects.flat_map(&:targets).each do |target|
        ld_flags_info[target] = target.resolved_build_setting('OTHER_LDFLAGS', true)
      end
      ld_flags_info
    end

    private

    def projects
      all_project_paths = workspace.file_references.map(&:path) if workspace
      all_project_paths = [project.path] if project

      all_project_paths.map do |project_path|
        Xcodeproj::Project.open(File.expand_path(project_path, @workspace_dir))
      end
    end
  end
end
