require 'net/http'
require 'active_support'

module Jekyll
  module DownloadFilter
    def data_for(platform, branch, tag, filename, ext)
      case platform
      when "docker"
        [
          "https://hub.docker.com/r/manageiq/manageiq/tags?page=1&name=#{tag}",
          no_file_info
        ]
      when "podified"
        [
          "/docs/get-started/kubernetes",
          no_file_info
        ]
      when "vagrant"
        release_url = url_at_releases(platform, filename, ext)
        [
          "https://app.vagrantup.com/manageiq/boxes/#{branch}",
          file_info_from_url(release_url)
        ]
      else
        release_url = url_at_releases(platform, filename, ext)
        [
          release_url,
          file_info_from_url(release_url)
        ]
      end
    end

    def on_click_for_download(platform, type_name, release_name)
      action = downloadable?(platform) ? 'download' : 'outbound'
      "ga('send', 'event', { eventCategory: 'Appliance', eventAction: '#{action}', eventLabel: '#{type_name} #{release_name}', transport: 'beacon' });"
    end

    private

    RELEASES_URL_PREFIX = "https://releases.manageiq.org"

    def url_at_releases(platform, filename, ext)
      "#{RELEASES_URL_PREFIX}/manageiq-#{platform}-#{filename}.#{ext}"
    end

    def file_info_from_url(url)
      return no_file_info if ENV["SKIP_FILE_INFO"]
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        response = http.request_head(uri.path)
        case response.code
        when '200'
          file_size = response['content-length'].to_f
          {
            "size" => ActiveSupport::NumberHelper.number_to_human_size(file_size),
            "md5"  => response['etag'].delete('"')
          }
        when '302'
          Jekyll.logger.info("Following redirect for #{url}...")
          file_info_from_url(response["location"])
        else
          Jekyll.logger.error("Jekyll::DownloadFilter.file_info_from_url(#{url})", "code=#{response.code}, message=#{response.message}")
          return no_file_info
        end
      end
    rescue => error
      Jekyll.logger.error("Jekyll::DownloadFilter.file_info_from_url(#{url})", "error=#{error.message}")
      return no_file_info
    end

    def downloadable?(platform)
      !["docker", "vagrant", "podified"].include?(platform)
    end

    def no_file_info
      { "size" => "NA", "md5" => "NA" }
    end
  end
end

Liquid::Template.register_filter(Jekyll::DownloadFilter)
