# frozen_string_literal: true

require "simplecov"
SimpleCov.start "rails" do
  command_name "Minitest"
  enable_coverage :branch
  track_files "{app,packages,lib}/**/*.rb"
end
