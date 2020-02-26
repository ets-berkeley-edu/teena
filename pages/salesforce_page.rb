class SalesforcePage

  include PageObject
  include Logging
  include Page

  text_area(:username, id: 'username')
  text_area(:password, id: 'password')
  button(:login_button, id: 'Login')
  link(:locations_link, xpath: '//a[contains(., "Locations")]')
  button(:new_location_button, xpath: '//a[@title="New"]')
  text_area(:location_agent_input, xpath: '//label[contains(., "Location Name")]/following-sibling::input')
  text_area(:location_room_input, xpath: '//label[contains(., "Room Number")]/following-sibling::input')
  link(:location_building_link, xpath: '//span[contains(., "Building")]/following-sibling::div//a')
  link(:location_type_link, xpath: '//span[contains(., "Type")]/following-sibling::div//a')
  link(:location_capability_link, xpath: '//span[contains(., "Recording Capabilities")]/following-sibling::div//a')
  button(:location_save_button, xpath: '//button[@title="Save"]')

  def location_building_option(name)
    link_element(xpath: "//a[contains(., \"#{name}\")]")
  end

  def location_type_option(name)
    link_element(xpath: "//a[contains(., \"#{name}\")]")
  end

  def location_capabilities_option(name)
    link_element(xpath: "//a[contains(., \"#{name}\")]")
  end

  def location_name(name)
    div_element(xpath: "//span[contains(., \"Location Name\")]/../following-sibling::div[contains(., \"#{name}\")]")
  end

  def location_building(name)
    div_element(xpath: "//span[contains(., \"Building\")]/../following-sibling::div[contains(., \"#{name}\")]")
  end

  def location_room(name)
    div_element(xpath: "//span[contains(., \"Room Number\")]/../following-sibling::div[contains(., \"#{name}\")]")
  end

  # Logs in to Salesforce sandbox
  def log_in
    logger.info 'Logging in to Salesforce'
    navigate_to SalesforceUtils.base_url
    wait_for_element_and_type(username_element, SalesforceUtils.login_credentials[:username])
    wait_for_element_and_type(password_element, SalesforceUtils.login_credentials[:password])
    wait_for_update_and_click login_button_element
  end

  # Creates a capture agent 'location' in Salesforce
  # @param agent [Hash]
  def create_location(agent)
    logger.info "Creating '#{agent['captureAgent']}'"
    sleep Utils.short_wait
    wait_for_load_and_click_js locations_link_element
    sleep Utils.short_wait
    wait_for_load_and_click_js new_location_button_element
    sleep Utils.short_wait
    wait_for_element_and_type_js(location_agent_input_element, agent['captureAgent'])
    wait_for_element_and_type_js(location_room_input_element, agent['room'])
    wait_for_update_and_click_js location_type_link_element
    wait_for_update_and_click_js location_type_option 'GA Classroom'
    wait_for_update_and_click_js location_capability_link_element
    wait_for_update_and_click_js location_capabilities_option agent['capability']
    wait_for_update_and_click_js location_building_link_element
    wait_for_update_and_click_js location_building_option agent['building']
    wait_for_update_and_click_js location_save_button_element

    sleep Utils.short_wait
    location_name(agent['captureAgent']).when_present 1
    location_building(agent['building']).when_present 1
    location_room(agent['room']).when_present 1
  end

end
