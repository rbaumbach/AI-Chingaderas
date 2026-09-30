# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"
require "uri"

class CodexRelease
  BASE_URL = "https://releases.openai.com/codex"
  TARGET = "aarch64-unknown-linux-musl"

  PACKAGE_NAME = "codex-package-#{TARGET}.tar.gz"
  CHECKSUM_NAME = "codex-package_SHA256SUMS"

  attr_reader :version

  def self.latest
    metadata = fetch_json("#{BASE_URL}/channels/latest")
    tag_name = metadata.fetch("tag_name")
    version = tag_name.delete_prefix("rust-v")

    new(version)
  end

  def initialize(version)
    @version = version
  end

  def package_url
    "#{release_base_url}/#{PACKAGE_NAME}"
  end

  def checksum_url
    "#{release_base_url}/#{CHECKSUM_NAME}"
  end

  def download_package(destination)
    self.class.download(package_url, destination)
  end

  def download_checksums(destination)
    self.class.download(checksum_url, destination)
  end

  def verify_package(package_path, checksum_path)
    expected = expected_package_sha256(checksum_path)
    actual = Digest::SHA256.file(package_path).hexdigest

    return true if actual == expected

    raise "Codex package checksum mismatch"
  end

  def extract_package(package_path, destination)
    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(destination)

    success = system(
      "tar",
      "-xzf",
      package_path,
      "-C",
      destination
    )

    raise "Failed to extract Codex package" unless success

    destination
  end

  private

  def release_base_url
    "#{BASE_URL}/releases/#{version}"
  end

  def expected_package_sha256(checksum_path)
    File.foreach(checksum_path) do |line|
      digest, filename = line.strip.split(/\s+/, 2)

      next unless filename == PACKAGE_NAME
      next unless digest&.match?(/\A[0-9a-fA-F]{64}\z/)

      return digest.downcase
    end

    raise "Could not find checksum for #{PACKAGE_NAME}"
  end

  class << self
    def fetch_json(url)
      JSON.parse(fetch(url))
    end

    def download(url, destination)
      uri = URI(url)

      FileUtils.mkdir_p(File.dirname(destination))

      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https"
      ) do |http|
        request = Net::HTTP::Get.new(uri)

        http.request(request) do |response|
          unless response.is_a?(Net::HTTPSuccess)
            raise "Download failed: #{response.code} #{response.message}"
          end

          File.open(destination, "wb") do |file|
            response.read_body do |chunk|
              file.write(chunk)
            end
          end
        end
      end

      destination
    end

    private

    def fetch(url)
      uri = URI(url)

      response = Net::HTTP.get_response(uri)

      unless response.is_a?(Net::HTTPSuccess)
        raise "Request failed: #{response.code} #{response.message}"
      end

      response.body
    end
  end
end
