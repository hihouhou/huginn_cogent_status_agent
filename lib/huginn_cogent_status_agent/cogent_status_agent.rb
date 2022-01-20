module Agents
  class CogentStatusAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_5m'

    description do
      <<-MD
      The Cogent agent fetches Cogent status and creates events if changes on net / dns / maintenance data.

      `debug` is used to verbose mode.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "status": {
              "status": "Normal",
              "description": "Welcome to the Cogent Communications status page.  There is nothing to report.",
              "name": "Cogent net_status"
            }
          }
    MD

    def default_options
      {
        'debug' => 'false',
        'expected_receive_period_in_days' => '2',
        'changes_only' => 'true'
      }
    end

    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :debug, type: :boolean

    def validate_options

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      check_status
    end

    private

    def check_status()

        uri = URI.parse("https://ecogent.cogentco.com/api/network-status")
        request = Net::HTTP::Get.new(uri)
        request["Connection"] = "keep-alive"
        request["Accept"] = "application/json, text/plain, */*"
        request["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36"
        request["X-Requested-With"] = "XMLHttpRequest"
        request["Sec-Gpc"] = "1"
        request["Sec-Fetch-Site"] = "same-origin"
        request["Sec-Fetch-Mode"] = "cors"
        request["Sec-Fetch-Dest"] = "empty"
        request["Referer"] = "https://ecogent.cogentco.com/network-status"
        request["Accept-Language"] = "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7"
        
        req_options = {
          use_ssl: uri.scheme == "https",
        }
        
        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end
      
      log "request  status : #{response.code}"

      payload = JSON.parse(response.body)

      if interpolated['debug'] == 'true'
        log payload
      end

        if interpolated['changes_only'] == 'true'
          if payload.to_s != memory['last_status']
            memory['last_status'] = payload.to_s
            last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil", ": null")
            last_status = JSON.parse(last_status)

            if interpolated['debug'] == 'true'
              log "last_status"
              log last_status
            end
            if payload['data']['dns_status'] != memory['last_status']['data']['dns_status']
              create_event :payload => { 'status' => { 'status' => payload['data']['dns_status'], 'description' => payload['data']['dns_description'], 'name' => "Cogent dns_status"}}
            end
            if payload['data']['net_status'] != memory['last_status']['data']['net_status']
              create_event :payload => { 'status' => { 'status' => payload['data']['net_status'], 'description' => payload['data']['net_description'], 'name' => "Cogent net_status"}}
            end
            if payload['data']['maintenance'] != memory['last_status']['data']['maintenance']
              create_event :payload => { 'status' => { 'maintenance' => payload['data']['maintenance'], 'name' => "Cogent maintenance"}}
            end
          end
        else
          create_event payload: payload
          if payload.to_s != memory['last_status']
            memory['last_status'] = payload.to_s
          end
        end
    end
  end
end
