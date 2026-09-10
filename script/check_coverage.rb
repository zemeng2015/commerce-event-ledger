#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "pathname"

root = Pathname.new(__dir__).parent.expand_path
result_path = root.join("coverage/.resultset.json")
abort "Missing raw SimpleCov results; run the tests with CI=true." unless result_path.file?
results = JSON.parse(result_path.read)
abort "Expected one current test-suite coverage result." unless results.size == 1
coverage = results.values.first.fetch("coverage")

# Docker's bind mount retains the host UID. Trust only this exact checkout for
# this read; do not alter the user's global Git ownership policy.
tracked, status = Open3.capture2("git", "-c", "safe.directory=#{root}", "ls-files", "-z", "app", "packages", "lib", chdir: root.to_s)
abort "Cannot enumerate tracked application sources." unless status.success?
expected = tracked.split("\0").select do |path|
  path.end_with?(".rb") && (path.start_with?("app/", "lib/") || path.match?(%r{\Apackages/[^/]+/app/}))
end
abort "No tracked application sources to measure." if expected.empty?

measured = expected.to_h do |relative|
  entry = coverage[root.join(relative).to_s]
  abort "Application file missing from coverage: #{relative}" unless entry
  lines = entry.fetch("lines").compact
  abort "Application file was not loaded during coverage: #{relative}" unless lines.any?(&:positive?)
  branches = entry.fetch("branches").values.flat_map(&:values)
  [ relative, { branches: branches.size, covered_branches: branches.count(&:positive?) } ]
end

total = measured.values.sum { |entry| entry.fetch(:branches) }
covered = measured.values.sum { |entry| entry.fetch(:covered_branches) }
abort "No actual branches measured; zero-denominator coverage is not evidence." if total.zero?
summary = {
  scope: "Implemented application, package and library sources; full release gates require separate evidence",
  files: measured,
  branches: total,
  covered_branches: covered,
  branch_percent: (100.0 * covered / total).round(2)
}
root.join("coverage/branch-summary.json").write(JSON.pretty_generate(summary) + "\n")
puts "Coverage: #{covered}/#{total} branches (#{summary.fetch(:branch_percent)}%); #{expected.size} source files loaded."
puts summary.fetch(:scope)
