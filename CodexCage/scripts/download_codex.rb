#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"
require "rubygems/package"
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
    request["User-Agent"] = "codex-cage-downloader"
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

  Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "codex-cage-downloader"
    request["Accept"] = "application/octet-stream"

    http.request(request) do |response|
      if response.is_a?(Net::HTTPRedirection)
        raise "Too many redirects while downloading #{url}" if redirects_left <= 0

        redirected_url = URI.join(url, response["location"]).to_s
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

  puts "Extracted Codex binary to #{destination_path}"
end

release = fetch_latest_release

tag = release.fetch("tag_name")

asset = release.fetch("assets").find do |item|
  item["name"] == ASSET_NAME
end

raise "Could not find #{ASSET_NAME} in release #{tag}" unless asset

FileUtils.mkdir_p(VENDOR_DIR)

archive_path = File.join(VENDOR_DIR, "codex-#{tag}.tar.gz")
binary_path = File.join(VENDOR_DIR, "codex")

puts "Downloading latest Codex executable..."
puts "Latest release: #{tag}"
puts "Asset: #{ASSET_NAME}"
puts "Saving archive: #{archive_path}"
puts "Saving binary:  #{binary_path}"

download_file(asset.fetch("browser_download_url"), archive_path)

verify_sha256!(
  archive_path,
  extract_sha256(asset["digest"])
)

extract_binary!(archive_path, binary_path)

puts
puts "Done."
puts "Codex #{tag} is ready for Docker:"
puts "  #{binary_path}"