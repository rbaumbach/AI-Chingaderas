#!/usr/bin/env ruby

# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"
require "rubygems/package"
require "tmpdir"
require "uri"
require "zlib"

LATEST_RELEASE_URL = "https://api.github.com/repos/openai/codex/releases/latest"

# Docker container target:
# Apple Silicon Mac -> Docker Desktop Linux ARM64
TARGET = "aarch64-unknown-linux-musl"

ASSETS = [
  {
    name: "codex-#{TARGET}.tar.gz",
    binary_name: "codex"
  },
  {
    name: "codex-code-mode-host-#{TARGET}.tar.gz",
    binary_name: "codex-code-mode-host"
  }
].freeze

# scripts/../vendor
VENDOR_DIR = File.expand_path("../vendor", __dir__)

MAX_REDIRECTS = 5

def fetch_latest_release
  uri = URI(LATEST_RELEASE_URL)

  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "codex-cage-updater"
    request["Accept"] = "application/vnd.github+json"
    http.request(request)
  end

  unless response.is_a?(Net::HTTPSuccess)
    raise "GitHub API request failed: #{response.code} #{response.message}"
  end

  JSON.parse(response.body)
end

def download_file(url, destination, redirects_left = MAX_REDIRECTS)
  uri = URI(url)

  Net::HTTP.start(
    uri.host,
    uri.port,
    use_ssl: uri.scheme == "https"
  ) do |http|
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "codex-cage-updater"
    request["Accept"] = "application/octet-stream"

    http.request(request) do |response|
      if response.is_a?(Net::HTTPRedirection)
        raise "Too many redirects while downloading #{url}" if redirects_left <= 0

        location = response["location"]
        raise "Redirect missing Location header for #{url}" unless location

        redirected_url = URI.join(url, location).to_s
        return download_file(redirected_url, destination, redirects_left - 1)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise "Download failed: #{response.code} #{response.message}"
      end

      File.open(destination, "wb") do |file|
        response.read_body { |chunk| file.write(chunk) }
      end
    end
  end
end

def extract_sha256(digest_value)
  return nil unless digest_value

  match = digest_value.match(/\Asha256:([0-9a-f]{64})\z/i)
  match && match[1].downcase
end

def verify_sha256!(file_path, expected_sha)
  raise "GitHub did not provide a SHA-256 for this asset." unless expected_sha

  actual_sha = Digest::SHA256.file(file_path).hexdigest

  puts "Expected SHA-256: #{expected_sha}"
  puts "Actual SHA-256:   #{actual_sha}"

  unless actual_sha == expected_sha
    raise "SHA-256 mismatch.\nExpected: #{expected_sha}\nActual:   #{actual_sha}"
  end

  puts "SHA-256 verified successfully."
end

def extract_binary!(archive_path, destination_path, binary_name)
  puts "Extracting #{binary_name}..."

  extracted = false

  Zlib::GzipReader.open(archive_path) do |gzip|
    Gem::Package::TarReader.new(gzip) do |tar|
      tar.each do |entry|
        next unless entry.file?
        next unless File.basename(entry.full_name).start_with?(binary_name)

        File.open(destination_path, "wb") do |file|
          file.write(entry.read)
        end

        FileUtils.chmod(0o755, destination_path)
        extracted = true
        break
      end
    end
  end

  raise "Could not find #{binary_name} inside #{archive_path}" unless extracted

  puts "Extracted #{binary_name}."
end

def installed_tag
  archives = Dir.glob(File.join(VENDOR_DIR, "codex-rust-v*.tar.gz"))

  return nil if archives.empty?

  File.basename(archives.first)
      .delete_prefix("codex-")
      .delete_suffix(".tar.gz")
end

def installation_complete?
  ASSETS.all? do |asset|
    File.exist?(File.join(VENDOR_DIR, asset.fetch(:binary_name)))
  end
end

release = fetch_latest_release
latest_tag = release.fetch("tag_name")
current_tag = installed_tag

if current_tag == latest_tag && installation_complete?
  puts "Codex is already up to date (#{latest_tag})."
  exit 0
end

puts "Codex update available:"
puts "  Current: #{current_tag || "none"}"
puts "  Latest:  #{latest_tag}"

unless installation_complete?
  puts "  Installation is missing one or more required Codex binaries."
end

release_assets = release.fetch("assets")

assets = ASSETS.map do |required_asset|
  asset = release_assets.find do |item|
    item["name"] == required_asset.fetch(:name)
  end

  unless asset
    raise "Could not find #{required_asset.fetch(:name)} in release #{latest_tag}"
  end

  required_asset.merge(
    download_url: asset.fetch("browser_download_url"),
    expected_sha: extract_sha256(asset["digest"])
  )
end

FileUtils.mkdir_p(VENDOR_DIR)

Dir.mktmpdir("codex-update") do |tmp_dir|
  prepared_assets = assets.map do |asset|
    binary_name = asset.fetch(:binary_name)

    archive_name = "#{binary_name}-#{latest_tag}.tar.gz"
    temporary_archive_path = File.join(tmp_dir, archive_name)
    temporary_binary_path = File.join(tmp_dir, binary_name)

    puts
    puts "Downloading #{asset.fetch(:name)}..."

    download_file(
      asset.fetch(:download_url),
      temporary_archive_path
    )

    verify_sha256!(
      temporary_archive_path,
      asset.fetch(:expected_sha)
    )

    extract_binary!(
      temporary_archive_path,
      temporary_binary_path,
      binary_name
    )

    asset.merge(
      archive_name: archive_name,
      temporary_archive_path: temporary_archive_path,
      temporary_binary_path: temporary_binary_path
    )
  end

  #
  # Do not touch the existing installation until every required asset:
  #
  # 1. Downloaded successfully
  # 2. Passed SHA-256 verification
  # 3. Extracted successfully
  #

  puts
  puts "Installing #{latest_tag}..."

  prepared_assets.each do |asset|
    installed_binary_path = File.join(
      VENDOR_DIR,
      asset.fetch(:binary_name)
    )

    installed_archive_path = File.join(
      VENDOR_DIR,
      asset.fetch(:archive_name)
    )

    FileUtils.mv(
      asset.fetch(:temporary_binary_path),
      installed_binary_path,
      force: true
    )

    FileUtils.cp(
      asset.fetch(:temporary_archive_path),
      installed_archive_path
    )
  end

  #
  # New binaries + archives are now installed successfully.
  # Remove old release archives.
  #

  ASSETS.each do |asset|
    binary_name = asset.fetch(:binary_name)
    current_archive_name = "#{binary_name}-#{latest_tag}.tar.gz"

    Dir.glob(File.join(VENDOR_DIR, "#{binary_name}-rust-v*.tar.gz")).each do |path|
      next if File.basename(path) == current_archive_name

      FileUtils.rm_f(path)
    end
  end
end

puts
puts "Done."
puts "Codex updated successfully:"
puts "  #{current_tag || "none"} -> #{latest_tag}"
puts
puts "Installed binaries:"
ASSETS.each do |asset|
  puts "  #{asset.fetch(:binary_name)}"
end
puts
puts "Rebuild CodexCage to use the new binaries."