class SquiggyWhiteboardsPage

  include PageObject
  include Logging
  include Page
  include SquiggyPages
  include SquiggyAssetLibraryMetadataForm
  include SquiggyWhiteboardEditForm

  def load_page(test)
    navigate_to test.course_site.whiteboards_url
    wait_until(Utils.medium_wait) { title == "#{SquiggyTool::WHITEBOARDS.name}" }
    hide_canvas_footer_and_popup
    switch_to_canvas_iframe
  end

  # CREATE WHITEBOARD

  link(:create_first_whiteboard_link, text: 'Create a whiteboard')
  button(:add_whiteboard_button, id: 'done-btn')

  def click_add_whiteboard
    wait_for_update_and_click add_whiteboard_button_element
  end

  def create_whiteboard(whiteboard)
    logger.info "Creating a new whiteboard named '#{whiteboard.title}'"
    click_add_whiteboard
    enter_whiteboard_title whiteboard.title
    whiteboard.collaborators.each { |u| enter_whiteboard_collaborator u }
    save_whiteboard
    verify_first_whiteboard whiteboard
  end

  # OPEN WHITEBOARD

  h2(:launch_failure, xpath: 'TODO')

  def create_and_open_whiteboard(whiteboard)
    create_whiteboard whiteboard
    open_whiteboard whiteboard
  end

  def open_whiteboard(whiteboard)
    logger.info "Opening whiteboard ID #{whiteboard.id}"
    click_whiteboard whiteboard
    shift_to_whiteboard_window(whiteboard)
  end

  # WHITEBOARDS LIST VIEW

  elements(:list_view_whiteboard, :div, xpath: '//div[contains(@id, "whiteboard-")]')
  elements(:list_view_whiteboard_title, :div, xpath: '//div[@class="v-card__text whiteboard-metadata"]/div[1]')

  def visible_whiteboard_titles
    list_view_whiteboard_title_elements.map { |el| el.text.strip }
  end

  def whiteboard_element(whiteboard)
    div_element(id: "whiteboard-#{whiteboard.id}")
  end

  def get_first_whiteboard_id
    wait_until(Utils.short_wait) { list_view_whiteboard_elements.any? }
    list_view_whiteboard_elements.first.attribute('id').split('-').last
  end

  def verify_first_whiteboard(whiteboard)
    sleep 1
    logger.debug "Verifying list view whiteboard title includes '#{whiteboard.title}'"
    wait_until(Utils.short_wait) do
      list_view_whiteboard_elements.any?
      sleep 2
      visible_whiteboard_titles.first.include? whiteboard.title
    end
    logger.info "New whiteboard ID is #{whiteboard.id = get_first_whiteboard_id}"
  end

  def click_whiteboard(whiteboard)
    wait_for_update_and_click whiteboard_element(whiteboard)
  end

  # SEARCH

  text_area(:simple_search_input, id: 'basic-search-input')
  button(:simple_search_button, id: 'search-btn')
  button(:open_adv_search_button, id: 'search-whiteboards-btn')
  text_field(:adv_search_keyword_input, id: 'adv-search-keywords-input')
  button(:adv_search_keyword_clear_button, xpath: '//input[@id="adv-search-keywords-input"]/../..//button')
  text_field(:adv_search_user_input, id: 'adv-search-user-select')
  button(:adv_search_user_clear_button, xpath: '//label[text()="Collaborator"]/..//button')
  div(:include_deleted_cbx, xpath: '//input[@id="include-deleted-checkbox"]/following-sibling::div')
  button(:adv_search_button, id: 'adv-search-btn')
  button(:cancel_adv_search_button, id: 'cancel-adv-search-btn')
  button(:reset_adv_search_button, id: 'reset-adv-search-btn')
  span(:wb_no_results_msg, xpath: '//span[text()="No matching whiteboards found"]')

  def simple_search(string)
    logger.info "Performing simple search for '#{string}'"
    cancel_adv_search_button if cancel_adv_search_button_element.visible?
    sleep Utils.click_wait
    wait_for_element_and_type_js(simple_search_input_element, string)
    wait_for_update_and_click simple_search_button_element
  end

  def wb_advanced_search(string, user, inc_deleted)
    logger.info 'Performing advanced search'
    wait_until(Utils.short_wait) { simple_search_button? || open_adv_search_button? || adv_search_button? }
    wait_for_update_and_click open_adv_search_button_element unless adv_search_keyword_input_element.visible?
    wait_for_update_and_click reset_adv_search_button_element if reset_adv_search_button?

    if string
      enter_squiggy_text(adv_search_keyword_input_element, string)
    end

    if user
      wait_for_update_and_click adv_search_user_input_element
      select_squiggy_option user.full_name
    end

    include_deleted_cbx_element.click if inc_deleted
    wait_for_update_and_click adv_search_button_element
    Utils.save_screenshot(@driver, "#{Time.now}") unless "#{@driver.browser}" == 'firefox'
  end
end
