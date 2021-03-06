#Fedena
#Copyright 2011 Foradian Technologies Private Limited
#
#This product includes software developed at
#Project Fedena - http://www.projectfedena.org/
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

# Configure your SMS API settings
require 'net/http'
require 'yaml'
require 'translator'

class SmsManager
  attr_accessor :recipients, :message

  def initialize(message, recipients)
    @recipients = recipients
    @message = message
    @config = SmsSetting.get_sms_config
    unless @config.blank?
      @authkey = @config['sms_settings']['authkey']
      @message = message
      @sender = @config['sms_settings']['sender']
      @route = @config['sms_settings']['route']
      @country = @config['sms_settings']['country']
      @sms_url = @config['sms_settings']['host_url']
    end
  end

  def perform
    if @config.present?
      message_log = SmsMessage.new(:body=> @message)
      message_log.save
      encoded_message = URI.encode(@message)
      request = "#{@sms_url}?authkey=#{@authkey}&sender=#{@sender}&message=#{@message}&route=#{@route}&country=#{@country}"
      @recipients.each do |recipient|
        cur_request = request + "&mobiles=#{recipient}"
        begin
          response = Net::HTTP.get_response(URI.parse(URI.encode(cur_request)))
          if response.body.present?
            message_log.sms_logs.create(:mobile=>recipient,:gateway_response=>response.body)
            if @success_code.present?
              if response.body.to_s.include? @success_code
                sms_count = Configuration.find_by_config_key("TotalSmsCount")
                new_count = sms_count.config_value.to_i + 1
                sms_count.update_attributes(:config_value=>new_count)
              end
            end
          end
        rescue Timeout::Error => e
          message_log.sms_logs.create(:mobile=>recipient,:gateway_response=>e.message)
        rescue Errno::ECONNREFUSED => e
          message_log.sms_logs.create(:mobile=>recipient,:gateway_response=>e.message)
        end
      end
    end
  end
end