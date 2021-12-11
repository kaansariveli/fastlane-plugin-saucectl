# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'open-uri'
require 'json'
require 'base64'
require 'timeout'
require 'fastlane_core/ui/ui'
require 'fileutils'

module Fastlane
  module Saucectl
    #
    # This class provides the functions required to interact with the saucectl api
    # for more information see: https://docs.saucelabs.com/dev/api/storage/
    #
    class Api
      UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

      def initialize(config)
        @config = config
        @encoded_auth_string = Base64.strict_encode64("#{@config['username']}:#{@config['api_key']}")
      end

      def available_devices
        path = 'v1/rdc/devices/available'
        https, url = build_http_request_for(path)
        request = Net::HTTP::Get.new(url)
        request['Authorization'] = "Basic #{@encoded_auth_string}"
        response = https.request(request)
        UI.user_error!("❌ Request failed: #{response.code} #{response.message}") unless response.kind_of?(Net::HTTPOK)

        response
      end

      def fetch_ios_devices
        devices = []
        get_devices = available_devices.body.split
        get_devices.each do |device|
          devices << device if device =~ /iPhone_.*/ || device =~ /iPad_.*/
        end
        devices
      end

      def fetch_android_devices
        devices = []
        get_devices = available_devices.body.split(',')
        get_devices.each do |device|
          devices << device unless device =~ /iPhone_.*/ || device =~ /iPad_.*/
        end
        devices
      end

      def retrieve_all_apps
        path = "v1/storage/files?q=#{@config['app_name']}&kind=#{@config['platform']}"
        https, url = build_http_request_for(path)
        request = Net::HTTP::Get.new(url)
        request['Authorization'] = "Basic #{@encoded_auth_string}"
        response = https.request(request)

        UI.user_error!("❌ Request failed: #{response.code} #{response.message}") unless response.kind_of?(Net::HTTPOK)

        response
      end

      def upload(description = nil)
        path = 'v1/storage/upload'
        https, url = build_http_request_for(path)
        request = Net::HTTP::Post.new(url)
        request['Authorization'] = "Basic #{@encoded_auth_string}"
        request.set_form(create_form_data_with(description), 'multipart/form-data')

        response = https.request(request)
        UI.user_error!("❌ Request failed: #{response.code} #{response.message}") unless response.kind_of?(Net::HTTPOK)

        response
      end

      def delete_app(path)
        https, url = build_http_request_for(path)
        request = Net::HTTP::Delete.new(url.path)
        request['Authorization'] = "Basic #{@encoded_auth_string}"
        response = https.request(request)
        UI.user_error!("❌ Request failed: #{response.code} #{response.message}") unless response.kind_of?(Net::HTTPOK)

        response
      end

      def base_url_for_region
        case @config['region']
        when 'eu' then base_url('eu-central-1')
        when 'us' then base_url('us-west-1')
        else UI.user_error!("❌ Invalid region #{@config['region']} \n Available regions: 'eu' and 'us'")
        end
      end

      def build_http_request_for(path)
        url = URI("#{base_url_for_region}/#{path}")
        https = Net::HTTP.new(url.host, url.port)
        https.use_ssl = true
        [https, url]
      end

      def create_form_data_with(description = nil)
        [
          ['payload',
           "@#{@config['app_path']}#{@config['app_name']}"],
          ['name', @config['app_name'],
           ['description', description.nil? ? 'uploaded via rsaucectl gem' : description]]
        ]
      end

      def base_url(region)
        "https://api.#{region}.saucelabs.com"
      end
    end
  end
end
