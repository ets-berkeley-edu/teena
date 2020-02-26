require_relative '../util/spec_helper'

begin

  include Logging

  agents_file = File.join(Utils.config_dir, 'test-data-matterhorn.json')
  agents = (JSON.parse File.read(agents_file))['agents']

  @driver = Utils.launch_browser
  @salesforce = SalesforcePage.new @driver
  @salesforce.log_in

  agents.each do |agent|

    begin
      @salesforce.create_location agent
      logger.warn "Created agent '#{agent['captureAgent']}'"
    rescue => e
      logger.error "Failed to create agent '#{agent['captureAgent']}'"
      Utils.log_error e
    end
  end

rescue => e
  logger.error 'Encountered unexpected error'
  Utils.log_error e
ensure
  Utils.quit_browser @driver
end
