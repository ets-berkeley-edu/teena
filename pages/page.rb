require_relative '../util/spec_helper'

module Page

  include PageObject
  include Logging

  div(:unauth_msg, xpath: '//*[contains(., "Unauthorized")]')

  def parse_json
    begin
      wait_until(Utils.medium_wait) do
        browser.find_element(xpath: '//pre')
        @parsed = JSON.parse browser.find_element(xpath: '//pre').text
      end
    rescue
      errors = Utils.get_js_errors @driver
      if errors.find { |e| e.include? 'the server responded with a status of 403' }
        fail('Access denied')
      end
    end
  end

  iframe(:canvas_iframe, xpath: '//iframe[starts-with(@id, "tool_content")]')

  def switch_to_frame(id)
    iframe_element(id: id).when_present Utils.short_wait
    @driver.switch_to.frame iframe_element(id: id).selenium_element.attribute('id')
  end

  def close_current_window
    @driver.close
  end

  def switch_to_main_content
    @driver.switch_to.default_content
  end

  def switch_to_window(index)
    @driver.switch_to.window @driver.window_handles[index]
  end

  def switch_to_first_window
    @driver.switch_to.window @driver.window_handles.first
  end

  def switch_to_last_window
    @driver.switch_to.window @driver.window_handles.last
  end

  def switch_to_window_handle(handle)
    @driver.switch_to.window handle
  end

  def window_count
    @driver.window_handles.length
  end

  # Switches browser focus into the Canvas LTI tool iframe. For Junction tests, pass the Junction base URL to verify that the tool
  # is configured with the right Junction environment before proceeding.
  # @param url [String]
  def switch_to_canvas_iframe(url = nil)
    hide_canvas_footer_and_popup
    canvas_iframe_element.when_present Utils.medium_wait
    if url
      wait_until(Utils.short_wait, "'#{url}' is not present") { i_frame_form_element? url }
      logger.warn "Found expected iframe base URL #{url}"
    end
    id = canvas_iframe_element.attribute('id')
    switch_to_frame id
  end

  # Whether or not an iframe containing a given URL exists
  # @param url [String]
  # @return [boolean]
  def i_frame_form_element?(url)
    logger.info "Looking for //form[contains(@action, '#{url}')]"
    form_element(xpath: "//form[contains(@action, '#{url}')]").exists?
  end

  # Hides the Canvas footer element in order to interact with elements hidden beneath it. Clicks once to set focus on the footer
  # and once again to hide it, with a retry in case the footer itself is obstructed.
  def hide_canvas_footer_and_popup
    if (browser_warning = button_element(xpath: '//li[@class="ic-flash-warning"]//button')).exists?
      browser_warning.click
      browser_warning.when_not_present Utils.short_wait
    end
    if (footer = div_element(id: 'element_toggler_0')).exists? && footer.visible?
      tries ||= 2
      begin
        execute_script('document.getElementById("element_toggler_0").style.display="none";')
      rescue => e
        Utils.log_error e
        (tries -= 1).zero? ? fail : (sleep 2; retry)
      end
    end
    if (new_user_panel = button_element(xpath: '//button[contains(., "Don\'t Show Again")]')).exists?
      logger.debug 'Dismissing annoying tutorial'
      js_click new_user_panel
      sleep 1
      if (confirm = button_element(xpath: '//button[contains(., "Okay")]')).exists?
        confirm.click
      end
    end
  end

  # Hides the BOA footer element in order to interact with elements hidden beneath it.
  def hide_boac_footer
    if (footer = div_element(id: 'fixed-warning-on-all-pages')).exists? && footer.visible?
      button_element(id: 'speedbird').click
      footer.when_not_present 1
    end
  end

  # Waits for an element to exist and to become visible
  # @param element [PageObject::Elements::Element]
  # @param timeout [Fixnum]
  def wait_for_element(element, timeout)
    element.when_present timeout
    element.when_visible timeout
    Utils.log_js_errors @driver
  end

  # Awaits an element for a given timeout then clicks it using WebDriver click method.
  # @param element [PageObject::Elements::Element]
  # @param timeout [Fixnum]
  def click_element(element, timeout, click_wait=nil)
    wait_for_element(element, timeout)
    hide_canvas_footer_and_popup
    hide_boac_footer
    scroll_to_element element
    sleep(click_wait || Utils.click_wait)
    el = element_element(element.locator)
    begin
      wait_until(Utils.short_wait) { el.enabled? }
      el.click
    rescue => e
      logger.warn e.message
      execute_script('arguments[0].click();', el)
    end
  end

  def js_click(element)
    begin
      tries ||= 2
      begin
        element.when_present Utils.short_wait
        execute_script('arguments[0].click();', element)
      rescue Selenium::WebDriver::Error::UnknownError
        (tries -= 1).zero? ? fail : retry
      end
    rescue
      # If clicking an element using JavaScript fails, then try the WebDriver method.
      click_element(element, Utils.short_wait)
    end
  end

  # Awaits an element for a given timeout then clicks it using JavaScript.
  # @param element [PageObject::Elements::Element]
  # @param timeout [Fixnum]
  def click_element_js(element, timeout)
    element.when_present timeout
    Utils.log_js_errors @driver
    js_click element
  end

  div(:canvas_footer, id: 'fixed_bottom')

  # Awaits an element for a short time then clicks it using WebDriver. Intended for DOM updates rather than page loads.
  # @param element [PageObject::Elements::Element]
  def wait_for_update_and_click(element, click_wait=nil)
    # When clicking Canvas elements, the footer might be in the way. Hide it if it exists.
    execute_script('arguments[0].style.hidden="hidden";', canvas_footer_element) if canvas_footer?
    click_element(element, Utils.short_wait, click_wait)
  end

  # Awaits an element for a moderate time then clicks it using WebDriver. Intended for page loads rather than DOM updates.
  # @param element [PageObject::Elements::Element]
  def wait_for_load_and_click(element, click_wait=nil)
    click_element(element, Utils.medium_wait, click_wait)
  end

  # Awaits an element for a short time, clicks it using WebDriver, removes existing text, and sends new text. Intended for placing text
  # in input or textarea elements.
  # @param element [PageObject::Elements::Element]
  # @param text [String]
  def wait_for_element_and_type(element, text, click_wait=nil)
    wait_for_update_and_click(element, click_wait)
    sleep(click_wait || Utils.click_wait)
    element.clear
    element.send_keys text unless text.to_s.empty?
  end

  def clear_input_value(element)
    element.text.length.times { hit_delete; hit_backspace } if element.text
    element.value.length.times { hit_delete; hit_backspace } if element.value
  end

  # Awaits a textbox element, clicks it, removes existing text, and sends new text.
  # @param element [PageObject::Elements::Element]
  # @param text [String]
  def wait_for_textbox_and_type(element, text)
    wait_for_update_and_click element
    sleep Utils.click_wait
    clear_input_value element
    element.click
    element.send_keys text
    sleep 1
  end

  # Awaits an element for a short time, clicks it using JavaScript, removes existing text, and sends new text. Intended for placing text
  # in input or textarea elements.
  # @param element [PageObject::Elements::Element]
  # @param text [String]
  def wait_for_element_and_type_js(element, text)
    wait_for_update_and_click element
    clear_input_value element
    element.send_keys text
  end

  def matching_option(select_element, option)
    select_element.options.find do |o|
      o.text.strip == option ||
        o.attribute('value') == option ||
        o.attribute('id')&.include?("-#{option.downcase}")
    end
  end

  # Awaits a select element for a short time, clicks it using JavaScript, waits for a certain option to appear, and selects that option.
  # @param select_element [PageObject::Elements::SelectList]
  # @param option [String]
  def wait_for_element_and_select(select_element, option)
    wait_for_update_and_click select_element
    sleep Utils.click_wait
    if option.instance_of? Selenium::WebDriver::Element
      option.click
    else
      matching_option(select_element, option).click
    end
  end

  # Returns true if a code block completes without error.
  # @return [boolean]
  def verify_block(&blk)
    begin
      return true if yield
    rescue => e
      logger.debug e.message
      false
    end
  end

  # Opens a new browser tab, switches focus to it, and returns its handle
  # @return [String]
  def open_new_window
    @driver.execute_script('window.open()')
    @driver.switch_to.window @driver.window_handles.last
    @driver.window_handle
  end

  # Clicks a link that should open in a new browser window and verifies that the expected page title loads on the new window.
  # @param link [PageObject::Elements::Element]
  # @param expected_page_title [String]
  # @return [boolean]
  def external_link_valid?(link, expected_page_title)
    begin
      original_window = @driver.window_handle
      wait_for_load_and_click link
      sleep 2
      if @driver.window_handles.length > 1
        @driver.switch_to.window @driver.window_handles.last
        wait_until(Utils.short_wait) { title_element(xpath: "//title[contains(.,\"#{expected_page_title}\")]").exists? }
        logger.debug "Found new window with title '#{expected_page_title}'"
        true
      else
        logger.error 'Link did not open in a new window'
        logger.debug "Expecting page title #{expected_page_title}, but visible page title is #{title}"
        false
      end
    rescue => e
      Utils.log_error e
      logger.debug "Expecting page title #{expected_page_title}, but visible page title is #{title}"
      false
    ensure
      if @driver.window_handles.length > 1
        # Handle any alert that might appear when opening the new window
        @driver.switch_to.alert.accept rescue Selenium::WebDriver::Error::NoSuchAlertError
        @driver.close
        # Handle any alert that might appear when closing the new window
        @driver.switch_to.alert.accept rescue Selenium::WebDriver::Error::NoSuchAlertError
      end
      @driver.switch_to.window original_window
    end
  end

  def scroll_to_top
    sleep Utils.click_wait
    execute_script('window.scrollTo(0, 0);')
  end

  # Uses JavaScript to scroll to the bottom of a page. This is a workaround for a WebDriver bug where certain elements
  # are not scrolled into focus prior to an interaction.
  def scroll_to_bottom
    sleep Utils.click_wait
    execute_script 'window.scrollTo(0, document.body.scrollHeight);'
  end

  # Uses JavaScript to scroll an element into view. If the attempt fails, it tries once more.
  # @param element [Element]
  def scroll_to_element(element)
    tries ||= 2
    begin
      execute_script('arguments[0].scrollIntoView(true);', element)
    rescue Selenium::WebDriver::Error::JavascriptError
      retry unless (tries -= 1).zero?
    end
  end

  # Hovers over an element with optional offsets, pausing to allow any events triggered by the action to occur.
  # @param element [Element]
  # @param horizontal_offset [Integer]
  # @param vertical_offset [Integer]
  def mouseover(element, horizontal_offset = nil, vertical_offset = nil)
    scroll_to_element element
    @driver.action.move_to(element.selenium_element, horizontal_offset, vertical_offset).perform
    sleep 1
  end

  def drag_and_drop(from_el, to_el)
    logger.info "Dragging and dropping from #{from_el.locator} to #{to_el.locator}"
    sleep Utils.click_wait
    browser.action.click_and_hold(from_el.selenium_element).perform
    sleep 1
    browser.action.move_to(to_el.selenium_element).perform
    sleep 1
    browser.action.release.perform
    sleep 1
  end

  def drag_and_drop_by(element, horizontal_offset, vertical_offset)
    logger.info "Dragging and dropping #{element.locator} to the right #{horizontal_offset} and down #{vertical_offset}"
    browser.action.drag_and_drop_by(element.selenium_element, horizontal_offset, vertical_offset).perform
  end

  def active_element
    browser.switch_to.active_element.tag
  end

  def pause_for_poller
    logger.info "Waiting for the Canvas poller for #{wait = Utils.medium_wait} seconds"
    sleep wait
  end

  def alert(&blk)
    yield
    sleep Utils.click_wait
    @driver.switch_to.alert.accept rescue Selenium::WebDriver::Error::NoSuchAlertError
  end

  # Hits the Delete key
  def hit_delete
    @driver.action.send_keys(:delete).perform
  end

  # Hits the Backspace key
  def hit_backspace
    @driver.action.send_keys(:backspace).perform
  end

  def hit_enter
    sleep Utils.click_wait
    @driver.action.send_keys(:enter).perform
  end

  # Hits the Escape key twice
  def hit_escape
    @driver.action.send_keys(:escape).perform
    sleep Utils.click_wait
    @driver.action.send_keys(:escape).perform
  end

  # Hits the Tab key
  def hit_tab
    @driver.action.send_keys(:tab).perform
  end

  def arrow_down
    sleep Utils.click_wait
    @driver.action.send_keys(:down).perform
  end

  def hit_forward_slash
    sleep Utils.click_wait
    @driver.action.send_keys('/').perform
  end

  def go_back
    logger.debug 'Clicking Back button'
    sleep Utils.click_wait
    @driver.navigate.back
  end

  def parse_downloaded_csv(link_el, file_name)
    Utils.prepare_download_dir
    wait_for_load_and_click link_el
    file_path = "#{Utils.download_dir}/#{file_name}"
    wait_until(Utils.long_wait) { Dir[file_path].any? }
    file = Dir[file_path].first
    sleep 2
    csv = CSV.read(file, headers: true, header_converters: :symbol)
    csv.map { |r| r.to_hash }
  end
end
