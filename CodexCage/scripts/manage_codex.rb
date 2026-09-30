# frozen_string_literal: true

require "fileutils"
require "json"

require_relative "codex_release"

ROOT_DIR = File.expand_path("..", __dir__)
VENDOR_DIR = File.join(ROOT_DIR, "vendor")

PACKAGE_PATH = File.join(VENDOR_DIR, CodexRelease::PACKAGE_NAME)
CHECKSUM_PATH = File.join(VENDOR_DIR, CodexRelease::CHECKSUM_NAME)

CODEX_DIR = File.join(VENDOR_DIR, "codex")
NEW_CODEX_DIR = File.join(VENDOR_DIR, "codex_new")
BACKUP_CODEX_DIR = File.join(VENDOR_DIR, "codex_backup")

def installed_version
  package_json_path = File.join(CODEX_DIR, "codex-package.json")

  return nil unless File.exist?(package_json_path)

  metadata = JSON.parse(File.read(package_json_path))
  metadata.fetch("version")
end

def install
  if installed_version
    raise "Codex #{installed_version} is already installed. Use update instead."
  end

  release = CodexRelease.latest

  puts "Installing Codex #{release.version}..."

  install_release(release)
end

def update
  current_version = installed_version

  unless current_version
    raise "Codex is not installed. Use install instead."
  end

  release = CodexRelease.latest

  if current_version == release.version
    puts "Codex #{current_version} is already up to date."
    return
  end

  puts "Updating Codex #{current_version} -> #{release.version}..."

  install_release(release)
end

def install_release(release)
  FileUtils.mkdir_p(VENDOR_DIR)

  puts "Downloading package..."
  release.download_package(PACKAGE_PATH)

  puts "Downloading checksums..."
  release.download_checksums(CHECKSUM_PATH)

  puts "Verifying package..."
  release.verify_package(PACKAGE_PATH, CHECKSUM_PATH)

  puts "Extracting package..."
  FileUtils.rm_rf(NEW_CODEX_DIR)
  release.extract_package(PACKAGE_PATH, NEW_CODEX_DIR)

  puts "Installing package..."

  FileUtils.rm_rf(BACKUP_CODEX_DIR)
  FileUtils.mv(CODEX_DIR, BACKUP_CODEX_DIR) if File.exist?(CODEX_DIR)

  begin
    FileUtils.mv(NEW_CODEX_DIR, CODEX_DIR)
    FileUtils.rm_rf(BACKUP_CODEX_DIR)

    puts "Installed Codex #{release.version}"
  rescue
    FileUtils.rm_rf(CODEX_DIR)

    if File.exist?(BACKUP_CODEX_DIR)
      FileUtils.mv(BACKUP_CODEX_DIR, CODEX_DIR)
    end

    raise
  ensure
    FileUtils.rm_rf(NEW_CODEX_DIR)
    FileUtils.rm_f(PACKAGE_PATH)
    FileUtils.rm_f(CHECKSUM_PATH)
  end
end

command = ARGV.first

case command
when "install"
  install
when "update"
  update
else
  puts "Usage:"
  puts "  ruby CodexCage/scripts/manage_codex.rb install"
  puts "  ruby CodexCage/scripts/manage_codex.rb update"
  exit 1
end
