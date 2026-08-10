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
ASSET_NAME = "codex-aarch64-unknown-linux-musl.tar.gz"

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

def extract_binary!(archive_path, destination_path)
  puts "Extracting executable..."

  extracted = false

  Zlib::GzipReader.open(archive_path) do |gzip|
    Gem::Package::TarReader.new(gzip) do |tar|
      tar.each do |entry|
        next unless entry.file?

        File.open(destination_path, "wb") do |file|
          file.write(entry.read)
        end

        FileUtils.chmod(0o755, destination_path)
        extracted = true
        break
      end
    end
  end

  raise "Could not find an executable inside #{archive_path}" unless extracted

  puts "Extracted Codex binary."
end

def installed_tag
  archives = Dir.glob(File.join(VENDOR_DIR, "codex-rust-v*.tar.gz"))

  return nil if archives.empty?

  File.basename(archives.first)
      .delete_prefix("codex-")
      .delete_suffix(".tar.gz")
end

release = fetch_latest_release
latest_tag = release.fetch("tag_name")
current_tag = installed_tag

if current_tag == latest_tag
  puts "Codex is already up to date (#{latest_tag})."
  exit 0
end

puts "Codex update available:"
puts "  Current: #{current_tag || "none"}"
puts "  Latest:  #{latest_tag}"

asset = release.fetch("assets").find do |item|
  item["name"] == ASSET_NAME
end

raise "Could not find #{ASSET_NAME} in release #{latest_tag}" unless asset

expected_sha = extract_sha256(asset["digest"])

FileUtils.mkdir_p(VENDOR_DIR)

Dir.mktmpdir("codex-update") do |tmp_dir|
  archive_name = "codex-#{latest_tag}.tar.gz"

  temporary_archive_path = File.join(tmp_dir, archive_name)
  temporary_binary_path = File.join(tmp_dir, "codex")

  puts "Downloading #{ASSET_NAME}..."

  download_file(
    asset.fetch("browser_download_url"),
    temporary_archive_path
  )

  verify_sha256!(
    temporary_archive_path,
    expected_sha
  )

  extract_binary!(
    temporary_archive_path,
    temporary_binary_path
  )

  #
  # Do not touch the existing installation until:
  #
  # 1. Download succeeded
  # 2. SHA-256 verification succeeded
  # 3. Extraction succeeded
  #

  puts "Installing #{latest_tag}..."

  installed_binary_path = File.join(VENDOR_DIR, "codex")
  installed_archive_path = File.join(VENDOR_DIR, archive_name)

  FileUtils.mv(
    temporary_binary_path,
    installed_binary_path,
    force: true
  )

  FileUtils.cp(
    temporary_archive_path,
    installed_archive_path
  )

  #
  # New binary + archive are now installed successfully.
  # Remove old release archives.
  #

  Dir.glob(File.join(VENDOR_DIR, "codex-rust-v*.tar.gz")).each do |path|
    next if path == installed_archive_path

    FileUtils.rm_f(path)
  end
end

puts
puts "Done."
puts "Codex updated successfully:"
puts "  #{current_tag || "none"} -> #{latest_tag}"
puts
puts "Rebuild CodexCage to use the new binary."