#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "rbconfig"
require "tmpdir"
require "yaml"

# Mutate only a disposable copy. Deliberately invalid references never enter
# the application checkout, its autoloader, or its recorded Packwerk debt.
root = Pathname.new(__dir__).parent.expand_path
tracked, status = Open3.capture2("git", "-c", "safe.directory=#{root}", "ls-files", "-z", chdir: root.to_s)
abort "Cannot enumerate tracked application files." unless status.success?

Dir.mktmpdir("commerce-event-ledger-boundaries-") do |directory|
  copy = Pathname.new(directory)
  tracked.split("\0").each do |relative|
    next unless relative.match?(%r{\A(?:app|config|lib|packages)/}) ||
      %w[Gemfile Gemfile.lock Rakefile package.yml packwerk.yml].include?(relative)

    destination = copy.join(relative)
    FileUtils.mkdir_p(destination.dirname)
    FileUtils.cp(root.join(relative), destination)
  end

  environment = { "BUNDLE_GEMFILE" => root.join("Gemfile").to_s, "RAILS_ENV" => "test" }
  check = lambda do |label, arguments, expected = nil|
    output, result = Open3.capture2e(environment, RbConfig.ruby, "-S", "bundle", "exec", "packwerk", *arguments, chdir: directory)
    correct = expected ? (!result.success? && output.match?(expected)) : result.success?
    abort "FAIL: #{label}\n#{output}" unless correct
    puts "PASS: #{label}"
  end

  probe = copy.join("app/services/boundary_probe.rb")
  FileUtils.mkdir_p(probe.dirname)
  public_reference = "class BoundaryProbe\n  def value\n    EventLedger::Envelope\n  end\nend\n"
  probe.write(public_reference)
  check.call("declared public interface is accessible", [ "check", "app/services/boundary_probe.rb" ])

  private_file = copy.join("packages/event_ledger/app/internal/event_ledger/boundary_private_probe.rb")
  FileUtils.mkdir_p(private_file.dirname)
  private_file.write("module EventLedger\n  class BoundaryPrivateProbe\n  end\nend\n")
  probe.write(public_reference.sub("EventLedger::Envelope", "EventLedger::BoundaryPrivateProbe"))
  check.call("cross-package private access is rejected", [ "check", "app/services/boundary_probe.rb" ], /Privacy violation:.*EventLedger::BoundaryPrivateProbe/)

  probe.write(public_reference)
  manifest_path = copy.join("package.yml")
  original_manifest = manifest_path.read
  manifest = YAML.safe_load(original_manifest)
  manifest.fetch("dependencies").delete("packages/event_ledger")
  manifest_path.write(YAML.dump(manifest))
  check.call("undeclared public dependency is rejected", [ "check", "app/services/boundary_probe.rb" ], /Dependency violation:.*EventLedger::Envelope/)

  manifest_path.write(original_manifest)
  ledger_manifest_path = copy.join("packages/event_ledger/package.yml")
  ledger_manifest = YAML.safe_load(ledger_manifest_path.read)
  ledger_manifest["dependencies"] = [ "." ]
  ledger_manifest_path.write(YAML.dump(ledger_manifest))
  check.call("cyclic package dependency is rejected", [ "validate" ], /cycl/i)
end
